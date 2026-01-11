#!/usr/bin/env python3
"""
Kubernetes Cluster Health Check Script
Provides comprehensive overview of cluster health status.
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

def check_nodes():
    """Check node health status."""
    print("\n=== NODE HEALTH ===")
    stdout, stderr, code = run_kubectl(["get", "nodes", "-o", "wide"])
    if code == 0:
        print(stdout)
        # Check for NotReady nodes
        stdout_json, _, _ = run_kubectl(["get", "nodes", "-o", "json"])
        if stdout_json:
            nodes = json.loads(stdout_json)
            not_ready = []
            for node in nodes.get("items", []):
                name = node["metadata"]["name"]
                for condition in node["status"].get("conditions", []):
                    if condition["type"] == "Ready" and condition["status"] != "True":
                        not_ready.append(name)
            if not_ready:
                print(f"\n WARNING: Not Ready nodes: {', '.join(not_ready)}")
    else:
        print(f"Error: {stderr}")

def check_system_pods():
    """Check system namespace pods."""
    print("\n=== SYSTEM PODS (kube-system) ===")
    stdout, stderr, code = run_kubectl([
        "get", "pods", "-n", "kube-system",
        "--field-selector=status.phase!=Running,status.phase!=Succeeded"
    ])
    if code == 0:
        if stdout.strip() and "No resources found" not in stdout:
            print("Unhealthy system pods:")
            print(stdout)
        else:
            print("All system pods healthy")
    else:
        print(f"Error: {stderr}")

def check_pending_pods():
    """Check for pending pods across all namespaces."""
    print("\n=== PENDING PODS ===")
    stdout, stderr, code = run_kubectl([
        "get", "pods", "--all-namespaces",
        "--field-selector=status.phase=Pending"
    ])
    if code == 0:
        if stdout.strip() and "No resources found" not in stdout:
            print(stdout)
        else:
            print("No pending pods")
    else:
        print(f"Error: {stderr}")

def check_failed_pods():
    """Check for failed pods across all namespaces."""
    print("\n=== FAILED PODS ===")
    stdout, stderr, code = run_kubectl([
        "get", "pods", "--all-namespaces",
        "--field-selector=status.phase=Failed"
    ])
    if code == 0:
        if stdout.strip() and "No resources found" not in stdout:
            print(stdout)
        else:
            print("No failed pods")
    else:
        print(f"Error: {stderr}")

def check_crashloop_pods():
    """Check for pods in CrashLoopBackOff."""
    print("\n=== CRASHLOOP PODS ===")
    stdout, stderr, code = run_kubectl([
        "get", "pods", "--all-namespaces", "-o", "json"
    ])
    if code == 0:
        pods = json.loads(stdout)
        crashloop = []
        for pod in pods.get("items", []):
            ns = pod["metadata"]["namespace"]
            name = pod["metadata"]["name"]
            for status in pod["status"].get("containerStatuses", []):
                waiting = status.get("state", {}).get("waiting", {})
                if waiting.get("reason") == "CrashLoopBackOff":
                    restarts = status.get("restartCount", 0)
                    crashloop.append(f"{ns}/{name} (restarts: {restarts})")
        if crashloop:
            for p in crashloop:
                print(f"  - {p}")
        else:
            print("No pods in CrashLoopBackOff")
    else:
        print(f"Error: {stderr}")

def check_recent_events():
    """Show recent warning events."""
    print("\n=== RECENT WARNING EVENTS ===")
    stdout, stderr, code = run_kubectl([
        "get", "events", "--all-namespaces",
        "--field-selector=type=Warning",
        "--sort-by=.lastTimestamp"
    ])
    if code == 0:
        lines = stdout.strip().split("\n")
        # Show last 10 warnings
        if len(lines) > 1:
            print("\n".join(lines[:1] + lines[-10:]))
        else:
            print("No recent warning events")
    else:
        print(f"Error: {stderr}")

def main():
    print("=" * 50)
    print("KUBERNETES CLUSTER HEALTH CHECK")
    print("=" * 50)

    check_nodes()
    check_system_pods()
    check_pending_pods()
    check_failed_pods()
    check_crashloop_pods()
    check_recent_events()

    print("\n" + "=" * 50)
    print("Health check complete")
    print("=" * 50)

if __name__ == "__main__":
    main()
