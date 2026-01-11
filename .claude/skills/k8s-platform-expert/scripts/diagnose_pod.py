#!/usr/bin/env python3
"""
Kubernetes Pod Diagnostics Script
Provides detailed pod-level troubleshooting information.
"""

import subprocess
import json
import sys

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

def diagnose_pod(namespace, pod_name):
    """Run comprehensive pod diagnostics."""

    print("=" * 60)
    print(f"POD DIAGNOSTICS: {namespace}/{pod_name}")
    print("=" * 60)

    # Get pod details
    stdout, stderr, code = run_kubectl([
        "get", "pod", pod_name, "-n", namespace, "-o", "json"
    ])

    if code != 0:
        print(f"Error getting pod: {stderr}")
        return

    pod = json.loads(stdout)

    # Basic info
    print("\n=== BASIC INFO ===")
    print(f"Name: {pod['metadata']['name']}")
    print(f"Namespace: {pod['metadata']['namespace']}")
    print(f"Node: {pod['spec'].get('nodeName', 'Not scheduled')}")
    print(f"Phase: {pod['status'].get('phase', 'Unknown')}")

    # Conditions
    print("\n=== CONDITIONS ===")
    for condition in pod["status"].get("conditions", []):
        status = "" if condition["status"] == "True" else ""
        print(f"  {status} {condition['type']}: {condition['status']}")
        if condition.get("reason"):
            print(f"      Reason: {condition['reason']}")
        if condition.get("message"):
            print(f"      Message: {condition['message']}")

    # Container statuses
    print("\n=== CONTAINER STATUSES ===")
    for status in pod["status"].get("containerStatuses", []):
        name = status["name"]
        ready = "" if status["ready"] else ""
        restarts = status["restartCount"]

        print(f"\n  Container: {name}")
        print(f"    Ready: {ready}")
        print(f"    Restarts: {restarts}")
        print(f"    Image: {status['image']}")

        # State analysis
        state = status.get("state", {})
        if "running" in state:
            print(f"    State: Running since {state['running'].get('startedAt', 'unknown')}")
        elif "waiting" in state:
            reason = state["waiting"].get("reason", "Unknown")
            message = state["waiting"].get("message", "")
            print(f"    State: Waiting - {reason}")
            if message:
                print(f"    Message: {message}")
        elif "terminated" in state:
            reason = state["terminated"].get("reason", "Unknown")
            exit_code = state["terminated"].get("exitCode", "?")
            print(f"    State: Terminated - {reason} (exit code: {exit_code})")

        # Last state (useful for restarts)
        last_state = status.get("lastState", {})
        if "terminated" in last_state:
            reason = last_state["terminated"].get("reason", "Unknown")
            exit_code = last_state["terminated"].get("exitCode", "?")
            finished = last_state["terminated"].get("finishedAt", "unknown")
            print(f"    Last Termination: {reason} (exit: {exit_code}) at {finished}")

    # Resource requests/limits
    print("\n=== RESOURCE CONFIGURATION ===")
    for container in pod["spec"].get("containers", []):
        name = container["name"]
        resources = container.get("resources", {})
        requests = resources.get("requests", {})
        limits = resources.get("limits", {})

        print(f"\n  Container: {name}")
        if requests:
            print(f"    Requests: CPU={requests.get('cpu', 'none')}, Memory={requests.get('memory', 'none')}")
        else:
            print("    Requests: Not set")
        if limits:
            print(f"    Limits: CPU={limits.get('cpu', 'none')}, Memory={limits.get('memory', 'none')}")
        else:
            print("    Limits: Not set")

    # Recent events
    print("\n=== RECENT EVENTS ===")
    stdout, stderr, code = run_kubectl([
        "get", "events", "-n", namespace,
        "--field-selector", f"involvedObject.name={pod_name}",
        "--sort-by=.lastTimestamp"
    ])
    if code == 0:
        lines = stdout.strip().split("\n")
        if len(lines) > 1:
            for line in lines[-10:]:
                print(f"  {line}")
        else:
            print("  No events found")

    # Recommendations
    print("\n=== RECOMMENDATIONS ===")
    recommendations = []

    phase = pod["status"].get("phase", "")
    if phase == "Pending":
        recommendations.append("Pod is Pending - check node resources and scheduling constraints")

    for status in pod["status"].get("containerStatuses", []):
        state = status.get("state", {})
        if "waiting" in state:
            reason = state["waiting"].get("reason", "")
            if reason == "ImagePullBackOff":
                recommendations.append(f"Image pull failed for {status['name']} - verify image name and registry access")
            elif reason == "CrashLoopBackOff":
                recommendations.append(f"Container {status['name']} is crash looping - check logs with: kubectl logs {pod_name} -n {namespace} --previous")

        if status["restartCount"] > 5:
            recommendations.append(f"High restart count ({status['restartCount']}) for {status['name']} - investigate stability issues")

    # Check for missing resources
    for container in pod["spec"].get("containers", []):
        resources = container.get("resources", {})
        if not resources.get("requests") and not resources.get("limits"):
            recommendations.append(f"No resource requests/limits for {container['name']} - consider adding for better scheduling")

    if recommendations:
        for rec in recommendations:
            print(f"   {rec}")
    else:
        print("   No immediate issues detected")

    print("\n" + "=" * 60)
    print("Diagnostics complete")
    print("=" * 60)

def main():
    if len(sys.argv) != 3:
        print("Usage: diagnose_pod.py <namespace> <pod-name>")
        sys.exit(1)

    namespace = sys.argv[1]
    pod_name = sys.argv[2]

    diagnose_pod(namespace, pod_name)

if __name__ == "__main__":
    main()
