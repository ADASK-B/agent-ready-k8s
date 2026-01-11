#!/usr/bin/env python3
"""
Helm Release Diagnostics Script
Provides comprehensive troubleshooting for Helm releases.
"""

import subprocess
import json
import sys

def run_command(cmd, timeout=30):
    """Run shell command and return output."""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1
    except Exception as e:
        return "", str(e), 1

def check_helm_available():
    """Check if helm is available."""
    stdout, stderr, code = run_command("helm version --short")
    if code != 0:
        print("Error: helm not found or not working")
        print(f"  {stderr}")
        return False
    print(f"Helm version: {stdout.strip()}")
    return True

def list_all_releases():
    """List all Helm releases across all namespaces."""
    print("\n=== ALL HELM RELEASES ===")

    stdout, stderr, code = run_command("helm list -A -o json")
    if code != 0:
        print(f"Error listing releases: {stderr}")
        return []

    releases = json.loads(stdout) if stdout.strip() else []

    if not releases:
        print("No Helm releases found")
        return []

    print(f"{'NAME':<25} {'NAMESPACE':<15} {'REVISION':<10} {'STATUS':<15} {'CHART':<30}")
    print("-" * 95)

    problem_releases = []
    for rel in releases:
        name = rel.get("name", "")
        namespace = rel.get("namespace", "")
        revision = rel.get("revision", "")
        status = rel.get("status", "")
        chart = rel.get("chart", "")

        # Status indicator
        status_icon = "" if status == "deployed" else "" if "pending" in status else ""

        print(f"{name:<25} {namespace:<15} {revision:<10} {status_icon} {status:<13} {chart:<30}")

        if status != "deployed":
            problem_releases.append(rel)

    return problem_releases

def diagnose_release(release_name, namespace):
    """Run detailed diagnostics on a specific Helm release."""
    print(f"\n{'=' * 60}")
    print(f"HELM RELEASE DIAGNOSTICS: {release_name} (ns: {namespace})")
    print("=" * 60)

    # Get release status
    stdout, stderr, code = run_command(f"helm status {release_name} -n {namespace} -o json")
    if code != 0:
        print(f"Error getting release status: {stderr}")
        return

    status = json.loads(stdout)

    # Basic info
    print("\n=== RELEASE INFO ===")
    info = status.get("info", {})
    print(f"Name: {status.get('name', 'N/A')}")
    print(f"Namespace: {status.get('namespace', 'N/A')}")
    print(f"Revision: {status.get('version', 'N/A')}")
    print(f"Status: {info.get('status', 'N/A')}")
    print(f"First Deployed: {info.get('first_deployed', 'N/A')}")
    print(f"Last Deployed: {info.get('last_deployed', 'N/A')}")
    print(f"Description: {info.get('description', 'N/A')}")

    # Chart info
    chart = status.get("chart", {}).get("metadata", {})
    print(f"\nChart: {chart.get('name', 'N/A')}")
    print(f"Chart Version: {chart.get('version', 'N/A')}")
    print(f"App Version: {chart.get('appVersion', 'N/A')}")

    # Get release history
    print("\n=== RELEASE HISTORY ===")
    stdout, stderr, code = run_command(f"helm history {release_name} -n {namespace} -o json")
    if code == 0 and stdout.strip():
        history = json.loads(stdout)
        print(f"{'REV':<6} {'STATUS':<15} {'DESCRIPTION':<40}")
        print("-" * 65)
        for entry in history[-5:]:  # Last 5 revisions
            rev = entry.get("revision", "")
            h_status = entry.get("status", "")
            desc = entry.get("description", "")[:40]
            status_icon = "" if h_status == "deployed" else "" if h_status == "superseded" else ""
            print(f"{rev:<6} {status_icon} {h_status:<13} {desc:<40}")
    else:
        print(f"Error getting history: {stderr}")

    # Get values
    print("\n=== APPLIED VALUES (non-default) ===")
    stdout, stderr, code = run_command(f"helm get values {release_name} -n {namespace}")
    if code == 0:
        if stdout.strip() and "null" not in stdout.lower():
            # Limit output
            lines = stdout.strip().split("\n")
            if len(lines) > 20:
                print("\n".join(lines[:20]))
                print(f"... ({len(lines) - 20} more lines)")
            else:
                print(stdout)
        else:
            print("Using all default values")
    else:
        print(f"Error getting values: {stderr}")

    # Check hooks
    print("\n=== HOOKS STATUS ===")
    stdout, stderr, code = run_command(f"helm get hooks {release_name} -n {namespace}")
    if code == 0 and stdout.strip():
        # Parse hooks from YAML
        hooks_count = stdout.count("# Source:")
        print(f"Found {hooks_count} hook(s)")

        # Check for hook jobs in namespace
        stdout_jobs, _, _ = run_command(f"kubectl get jobs -n {namespace} -l 'app.kubernetes.io/managed-by=Helm' -o json")
        if stdout_jobs:
            jobs = json.loads(stdout_jobs)
            for job in jobs.get("items", []):
                job_name = job["metadata"]["name"]
                succeeded = job["status"].get("succeeded", 0)
                failed = job["status"].get("failed", 0)

                if failed > 0:
                    print(f"   Hook job {job_name} failed")
                elif succeeded > 0:
                    print(f"   Hook job {job_name} succeeded")
                else:
                    print(f"   Hook job {job_name} still running")
    else:
        print("No hooks defined")

    # Get notes
    print("\n=== RELEASE NOTES ===")
    stdout, stderr, code = run_command(f"helm get notes {release_name} -n {namespace}")
    if code == 0 and stdout.strip():
        lines = stdout.strip().split("\n")
        if len(lines) > 15:
            print("\n".join(lines[:15]))
            print("... (truncated)")
        else:
            print(stdout)
    else:
        print("No release notes")

    # Check deployed resources
    print("\n=== DEPLOYED RESOURCES STATUS ===")
    stdout, stderr, code = run_command(f"helm get manifest {release_name} -n {namespace}")
    if code == 0:
        # Count resources by kind
        kinds = {}
        for line in stdout.split("\n"):
            if line.startswith("kind:"):
                kind = line.split(":")[1].strip()
                kinds[kind] = kinds.get(kind, 0) + 1

        print("Resources deployed:")
        for kind, count in sorted(kinds.items()):
            print(f"  - {kind}: {count}")

        # Check actual resource status
        print("\nResource Health:")
        for kind in ["Deployment", "StatefulSet", "DaemonSet"]:
            if kind in kinds:
                stdout_res, _, _ = run_command(
                    f"kubectl get {kind.lower()} -n {namespace} -l 'app.kubernetes.io/instance={release_name}' -o json"
                )
                if stdout_res:
                    resources = json.loads(stdout_res)
                    for res in resources.get("items", []):
                        name = res["metadata"]["name"]
                        if kind == "Deployment":
                            ready = res["status"].get("readyReplicas", 0)
                            desired = res["spec"].get("replicas", 0)
                            status_icon = "" if ready == desired else ""
                            print(f"  {status_icon} {kind}/{name}: {ready}/{desired} ready")
                        elif kind == "StatefulSet":
                            ready = res["status"].get("readyReplicas", 0)
                            desired = res["spec"].get("replicas", 0)
                            status_icon = "" if ready == desired else ""
                            print(f"  {status_icon} {kind}/{name}: {ready}/{desired} ready")

    # Recommendations
    print("\n=== RECOMMENDATIONS ===")
    recommendations = []

    release_status = info.get("status", "")

    if release_status == "pending-install":
        recommendations.append("Release stuck in pending-install - check for blocking webhooks or resource quotas")
        recommendations.append("Try: helm uninstall " + release_name + " -n " + namespace + " && helm install ...")

    if release_status == "pending-upgrade":
        recommendations.append("Release stuck in pending-upgrade - previous upgrade may have timed out")
        recommendations.append("Try: helm rollback " + release_name + " -n " + namespace)

    if release_status == "failed":
        recommendations.append("Release failed - check history for error details")
        recommendations.append("Try rolling back: helm rollback " + release_name + " <revision> -n " + namespace)

    if release_status == "uninstalling":
        recommendations.append("Release stuck uninstalling - finalizers may be blocking deletion")
        recommendations.append("Check: kubectl get all -n " + namespace + " -l app.kubernetes.io/instance=" + release_name)

    if not recommendations:
        recommendations.append("No issues detected with Helm release")

    for rec in recommendations:
        print(f"   {rec}")

def check_pending_operations():
    """Check for any stuck Helm operations."""
    print("\n=== PENDING HELM OPERATIONS ===")

    stdout, stderr, code = run_command("helm list -A -o json --pending")
    if code != 0:
        print(f"Error: {stderr}")
        return

    pending = json.loads(stdout) if stdout.strip() else []

    if pending:
        print(f"Found {len(pending)} pending operation(s):")
        for rel in pending:
            print(f"  - {rel['namespace']}/{rel['name']}: {rel['status']}")
    else:
        print("No pending operations")

def main():
    print("=" * 60)
    print("HELM DIAGNOSTICS")
    print("=" * 60)

    if not check_helm_available():
        sys.exit(1)

    # Check if specific release provided
    if len(sys.argv) >= 3:
        release_name = sys.argv[1]
        namespace = sys.argv[2]
        diagnose_release(release_name, namespace)
    elif len(sys.argv) == 2:
        print("Usage: diagnose_helm.py <release-name> <namespace>")
        print("Or run without arguments to list all releases")
        sys.exit(1)
    else:
        # List all releases
        problem_releases = list_all_releases()
        check_pending_operations()

        if problem_releases:
            print(f"\n Found {len(problem_releases)} release(s) with issues:")
            for rel in problem_releases:
                print(f"  - {rel['namespace']}/{rel['name']}: {rel['status']}")
            print("\nRun with release name and namespace for detailed diagnostics:")
            print("  python3 diagnose_helm.py <release-name> <namespace>")

    print("\n" + "=" * 60)
    print("Diagnostics complete")
    print("=" * 60)

if __name__ == "__main__":
    main()
