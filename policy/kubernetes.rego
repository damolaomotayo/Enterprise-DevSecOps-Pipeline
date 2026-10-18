# Policy as code: rules every Deployment must satisfy before it can ship.
# "deny" rules fail the pipeline. "warn" rules are reported but do not fail it.
# Run by conftest (pipeline/policy.sh).
package main

import rego.v1

pod_spec := input.spec.template.spec

containers := pod_spec.containers

# --- deny: must be fixed -------------------------------------------------

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not runs_as_non_root(c)
	msg := sprintf("container '%s' must run as non-root (securityContext.runAsNonRoot: true)", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	c.securityContext.privileged == true
	msg := sprintf("container '%s' must not be privileged", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not c.securityContext.allowPrivilegeEscalation == false
	msg := sprintf("container '%s' must set allowPrivilegeEscalation: false", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not c.securityContext.readOnlyRootFilesystem == true
	msg := sprintf("container '%s' must set readOnlyRootFilesystem: true", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not drops_all_capabilities(c)
	msg := sprintf("container '%s' must drop ALL capabilities", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not contains(c.image, ":")
	msg := sprintf("container '%s' image '%s' must have an explicit tag or digest", [c.name, c.image])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	endswith(c.image, ":latest")
	msg := sprintf("container '%s' must not use the mutable ':latest' tag", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not c.resources.limits.cpu
	msg := sprintf("container '%s' must set a CPU limit", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	some c in containers
	not c.resources.limits.memory
	msg := sprintf("container '%s' must set a memory limit", [c.name])
}

deny contains msg if {
	input.kind == "Deployment"
	pod_spec.hostNetwork == true
	msg := "pods must not use the host network"
}

# --- warn: should be fixed ----------------------------------------------

warn contains msg if {
	input.kind == "Deployment"
	input.spec.replicas < 2
	msg := "run at least 2 replicas for availability"
}

warn contains msg if {
	input.kind == "Deployment"
	some c in containers
	not c.readinessProbe
	msg := sprintf("container '%s' should define a readinessProbe", [c.name])
}

# --- helpers ---------------------------------------------------------------

drops_all_capabilities(c) if "ALL" in c.securityContext.capabilities.drop

# Non-root can be set on the container or once for the whole pod.
runs_as_non_root(c) if c.securityContext.runAsNonRoot == true

runs_as_non_root(_) if pod_spec.securityContext.runAsNonRoot == true
