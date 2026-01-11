#!/usr/bin/env python3
"""
ArgoCD Application Diagnostics Script
Provides comprehensive troubleshooting for ArgoCD applications.
"""

import subprocess
import json
import sys

def run_command(cmd):
    """Run shell command and return output."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1
    except Exception as e:
        return "", str(e), 1

def run_kubectl(args):
    """Run kubectl command and return output."""
    try:
        result = subprocess.run(
            ["kubectl"] + args,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1
    except FileNotFoundError:
        return "", "kubectl not found", 1

def check_argocd_health():
    """Check ArgoCD system health."""
    print("\n=== ARGOCD SYSTEM HEALTH ===")

    # Check ArgoCD pods
    stdout, stderr, code = run_kubectl([
        "get", "pods", "-n", "argocd", "-o", "wide"
    ])
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")
        return False

    # Check for unhealthy pods
    stdout, stderr, code = run_kubectl([
        "get", "pods", "-n", "argocd", "-o", "json"
    ])
    if code == 0:
        pods = json.loads(stdout)
        unhealthy = []
        for pod in pods.get("items", []):
            name = pod["metadata"]["name"]
            phase = pod["status"].get("phase", "Unknown")
            if phase not in ["Running", "Succeeded"]:
                unhealthy.append(f"{name} ({phase})")
            else:
                for status in pod["status"].get("containerStatuses", []):
                    if not status.get("ready", False):
                        unhealthy.append(f"{name} (not ready)")

        if unhealthy:
            print(f"\n WARNING: Unhealthy ArgoCD pods:")
            for p in unhealthy:
                print(f"  - {p}")
            return False
        else:
            print("\n All ArgoCD pods healthy")

    return True

def list_applications():
    """List all ArgoCD applications and their status."""
    print("\n=== ARGOCD APPLICATIONS ===")

    stdout, stderr, code = run_kubectl([
        "get", "applications", "-n", "argocd", "-o", "json"
    ])

    if code != 0:
        print(f"Error getting applications: {stderr}")
        return []

    apps = json.loads(stdout)
    app_list = []

    print(f"{'NAME':<30} {'SYNC':<12} {'HEALTH':<12} {'NAMESPACE':<15}")
    print("-" * 70)

    for app in apps.get("items", []):
        name = app["metadata"]["name"]
        sync_status = app.get("status", {}).get("sync", {}).get("status", "Unknown")
        health_status = app.get("status", {}).get("health", {}).get("status", "Unknown")
        dest_ns = app.get("spec", {}).get("destination", {}).get("namespace", "default")

        # Status indicators
        sync_icon = "" if sync_status == "Synced" else ""
        health_icon = "" if health_status == "Healthy" else "" if health_status == "Progressing" else ""

        print(f"{name:<30} {sync_icon} {sync_status:<10} {health_icon} {health_status:<10} {dest_ns:<15}")
        app_list.append({
            "name": name,
            "sync": sync_status,
            "health": health_status
        })

    return app_list

def diagnose_application(app_name):
    """Run detailed diagnostics on a specific application."""
    print(f"\n{'=' * 60}")
    print(f"APPLICATION DIAGNOSTICS: {app_name}")
    print("=" * 60)

    # Get application details
    stdout, stderr, code = run_kubectl([
        "get", "application", app_name, "-n", "argocd", "-o", "json"
    ])

    if code != 0:
        print(f"Error getting application: {stderr}")
        return

    app = json.loads(stdout)

    # Basic info
    print("\n=== BASIC INFO ===")
    spec = app.get("spec", {})
    status = app.get("status", {})

    print(f"Name: {app_name}")
    print(f"Project: {spec.get('project', 'default')}")
    print(f"Source Repo: {spec.get('source', {}).get('repoURL', 'N/A')}")
    print(f"Source Path: {spec.get('source', {}).get('path', 'N/A')}")
    print(f"Target Revision: {spec.get('source', {}).get('targetRevision', 'HEAD')}")
    print(f"Destination Server: {spec.get('destination', {}).get('server', 'N/A')}")
    print(f"Destination Namespace: {spec.get('destination', {}).get('namespace', 'default')}")

    # Sync status
    print("\n=== SYNC STATUS ===")
    sync = status.get("sync", {})
    sync_status = sync.get("status", "Unknown")
    revision = sync.get("revision", "N/A")

    sync_icon = "" if sync_status == "Synced" else ""
    print(f"Status: {sync_icon} {sync_status}")
    print(f"Revision: {revision}")

    if sync_status != "Synced":
        compared_to = sync.get("comparedTo", {})
        print(f"Compared Source: {compared_to.get('source', {}).get('targetRevision', 'N/A')}")

    # Health status
    print("\n=== HEALTH STATUS ===")
    health = status.get("health", {})
    health_status = health.get("status", "Unknown")
    health_message = health.get("message", "")

    health_icon = "" if health_status == "Healthy" else "" if health_status == "Progressing" else ""
    print(f"Status: {health_icon} {health_status}")
    if health_message:
        print(f"Message: {health_message}")

    # Resource status
    print("\n=== RESOURCE STATUS ===")
    resources = status.get("resources", [])

    if resources:
        unhealthy_resources = []
        for res in resources:
            res_health = res.get("health", {}).get("status", "Unknown")
            res_sync = res.get("status", "Unknown")

            if res_health not in ["Healthy", ""] or res_sync != "Synced":
                unhealthy_resources.append({
                    "kind": res.get("kind"),
                    "name": res.get("name"),
                    "namespace": res.get("namespace", "N/A"),
                    "health": res_health,
                    "sync": res_sync,
                    "message": res.get("health", {}).get("message", "")
                })

        print(f"Total Resources: {len(resources)}")
        print(f"Unhealthy/OutOfSync: {len(unhealthy_resources)}")

        if unhealthy_resources:
            print("\nProblematic Resources:")
            for res in unhealthy_resources:
                print(f"  - {res['kind']}/{res['name']} (ns: {res['namespace']})")
                print(f"    Health: {res['health']}, Sync: {res['sync']}")
                if res['message']:
                    print(f"    Message: {res['message']}")
    else:
        print("No resources found")

    # Conditions
    print("\n=== CONDITIONS ===")
    conditions = status.get("conditions", [])
    if conditions:
        for cond in conditions:
            cond_type = cond.get("type", "Unknown")
            message = cond.get("message", "No message")
            print(f"  {cond_type}: {message}")
    else:
        print("  No conditions")

    # Operation state (last sync)
    print("\n=== LAST OPERATION ===")
    operation = status.get("operationState", {})
    if operation:
        phase = operation.get("phase", "Unknown")
        message = operation.get("message", "")
        started = operation.get("startedAt", "N/A")
        finished = operation.get("finishedAt", "N/A")

        phase_icon = "" if phase == "Succeeded" else "" if phase == "Running" else ""
        print(f"Phase: {phase_icon} {phase}")
        print(f"Started: {started}")
        print(f"Finished: {finished}")
        if message:
            print(f"Message: {message}")

        # Sync result details
        sync_result = operation.get("syncResult", {})
        if sync_result:
            resources_synced = sync_result.get("resources", [])
            failed_resources = [r for r in resources_synced if r.get("status") != "Synced"]
            if failed_resources:
                print("\nFailed Resources:")
                for res in failed_resources:
                    print(f"  - {res.get('kind')}/{res.get('name')}: {res.get('message', 'No message')}")
    else:
        print("  No operation recorded")

    # Recommendations
    print("\n=== RECOMMENDATIONS ===")
    recommendations = []

    if sync_status == "OutOfSync":
        recommendations.append("Application is OutOfSync - run 'argocd app sync " + app_name + "' to synchronize")

    if health_status == "Degraded":
        recommendations.append("Application health is Degraded - check resource status above for failing resources")

    if health_status == "Progressing":
        recommendations.append("Application is still progressing - wait for deployment to complete or check for stuck resources")

    if health_status == "Missing":
        recommendations.append("Resources are missing - verify manifests exist in source repository")

    for res in status.get("resources", []):
        res_health = res.get("health", {}).get("status", "")
        if res_health == "Degraded":
            recommendations.append(f"Check {res.get('kind')}/{res.get('name')} - kubectl describe {res.get('kind').lower()} {res.get('name')} -n {res.get('namespace', 'default')}")

    if recommendations:
        for rec in recommendations:
            print(f"   {rec}")
    else:
        print("   No issues detected")

def check_recent_events():
    """Show recent ArgoCD events."""
    print("\n=== RECENT ARGOCD EVENTS ===")
    stdout, stderr, code = run_kubectl([
        "get", "events", "-n", "argocd",
        "--sort-by=.lastTimestamp"
    ])
    if code == 0:
        lines = stdout.strip().split("\n")
        if len(lines) > 1:
            print("\n".join(lines[:1] + lines[-10:]))
        else:
            print("No recent events")
    else:
        print(f"Error: {stderr}")

def main():
    print("=" * 60)
    print("ARGOCD DIAGNOSTICS")
    print("=" * 60)

    # Check if specific app provided
    app_name = sys.argv[1] if len(sys.argv) > 1 else None

    # Always check ArgoCD health first
    argocd_healthy = check_argocd_health()

    if not argocd_healthy:
        print("\n ArgoCD system is not healthy. Fix system issues before diagnosing applications.")

    if app_name:
        # Diagnose specific application
        diagnose_application(app_name)
    else:
        # List all applications
        apps = list_applications()

        # Check for problematic apps
        problem_apps = [a for a in apps if a["sync"] != "Synced" or a["health"] not in ["Healthy", "Progressing"]]

        if problem_apps:
            print(f"\n Found {len(problem_apps)} application(s) with issues:")
            for app in problem_apps:
                print(f"  - {app['name']}: Sync={app['sync']}, Health={app['health']}")
            print("\nRun with app name for detailed diagnostics:")
            print(f"  python3 diagnose_argocd.py <app-name>")

    check_recent_events()

    print("\n" + "=" * 60)
    print("Diagnostics complete")
    print("=" * 60)

if __name__ == "__main__":
    main()
