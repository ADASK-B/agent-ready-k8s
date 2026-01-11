#!/usr/bin/env python3
"""
Kubernetes Namespace Health Check Script
Provides comprehensive namespace-level diagnostics.
"""

import subprocess
import json
import sys
import argparse

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

def check_pods(namespace):
    """Check pod health in namespace."""
    print(f"\n=== PODS in {namespace} ===")
    stdout, stderr, code = run_kubectl([
        "get", "pods", "-n", namespace, "-o", "wide"
    ])
    if code == 0:
        print(stdout)

        # Analyze pod states
        stdout_json, _, _ = run_kubectl([
            "get", "pods", "-n", namespace, "-o", "json"
        ])
        if stdout_json:
            pods = json.loads(stdout_json)
            issues = []
            for pod in pods.get("items", []):
                name = pod["metadata"]["name"]
                phase = pod["status"].get("phase", "Unknown")

                if phase not in ["Running", "Succeeded"]:
                    issues.append(f"  - {name}: {phase}")

                for status in pod["status"].get("containerStatuses", []):
                    waiting = status.get("state", {}).get("waiting", {})
                    reason = waiting.get("reason", "")
                    if reason in ["CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull"]:
                        issues.append(f"  - {name}: {reason}")

            if issues:
                print("\n ISSUES FOUND:")
                for issue in issues:
                    print(issue)
    else:
        print(f"Error: {stderr}")

def check_services(namespace):
    """Check services in namespace."""
    print(f"\n=== SERVICES in {namespace} ===")
    stdout, stderr, code = run_kubectl([
        "get", "svc", "-n", namespace
    ])
    if code == 0:
        print(stdout)

        # Check endpoints
        stdout_ep, _, _ = run_kubectl([
            "get", "endpoints", "-n", namespace, "-o", "json"
        ])
        if stdout_ep:
            endpoints = json.loads(stdout_ep)
            no_endpoints = []
            for ep in endpoints.get("items", []):
                name = ep["metadata"]["name"]
                subsets = ep.get("subsets", [])
                if not subsets:
                    no_endpoints.append(name)
            if no_endpoints:
                print(f"\n WARNING: Services without endpoints: {', '.join(no_endpoints)}")
    else:
        print(f"Error: {stderr}")

def check_deployments(namespace):
    """Check deployments in namespace."""
    print(f"\n=== DEPLOYMENTS in {namespace} ===")
    stdout, stderr, code = run_kubectl([
        "get", "deployments", "-n", namespace
    ])
    if code == 0:
        print(stdout)
    else:
        print(f"Error: {stderr}")

def check_pvcs(namespace):
    """Check PVCs in namespace."""
    print(f"\n=== PERSISTENT VOLUME CLAIMS in {namespace} ===")
    stdout, stderr, code = run_kubectl([
        "get", "pvc", "-n", namespace
    ])
    if code == 0:
        if "No resources found" in stdout:
            print("No PVCs in namespace")
        else:
            print(stdout)
            # Check for pending PVCs
            stdout_json, _, _ = run_kubectl([
                "get", "pvc", "-n", namespace, "-o", "json"
            ])
            if stdout_json:
                pvcs = json.loads(stdout_json)
                pending = [
                    pvc["metadata"]["name"]
                    for pvc in pvcs.get("items", [])
                    if pvc["status"].get("phase") == "Pending"
                ]
                if pending:
                    print(f"\n WARNING: Pending PVCs: {', '.join(pending)}")
    else:
        print(f"Error: {stderr}")

def check_events(namespace, limit=10):
    """Check recent events in namespace."""
    print(f"\n=== RECENT EVENTS in {namespace} (last {limit}) ===")
    stdout, stderr, code = run_kubectl([
        "get", "events", "-n", namespace,
        "--sort-by=.lastTimestamp"
    ])
    if code == 0:
        lines = stdout.strip().split("\n")
        if len(lines) > 1:
            # Header + last N events
            print(lines[0])
            for line in lines[-(limit):]:
                print(line)
        else:
            print("No events found")
    else:
        print(f"Error: {stderr}")

def check_resource_quota(namespace):
    """Check resource quotas in namespace."""
    print(f"\n=== RESOURCE QUOTAS in {namespace} ===")
    stdout, stderr, code = run_kubectl([
        "get", "resourcequota", "-n", namespace
    ])
    if code == 0:
        if "No resources found" in stdout:
            print("No resource quotas defined")
        else:
            print(stdout)
    else:
        print(f"Error: {stderr}")

def main():
    parser = argparse.ArgumentParser(description="Check namespace health")
    parser.add_argument("namespace", help="Namespace to check")
    parser.add_argument("--events", type=int, default=10, help="Number of events to show")
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args()

    namespace = args.namespace

    print("=" * 50)
    print(f"NAMESPACE HEALTH CHECK: {namespace}")
    print("=" * 50)

    check_pods(namespace)
    check_services(namespace)
    check_deployments(namespace)
    check_pvcs(namespace)
    check_resource_quota(namespace)
    check_events(namespace, args.events)

    print("\n" + "=" * 50)
    print("Namespace check complete")
    print("=" * 50)

if __name__ == "__main__":
    main()
