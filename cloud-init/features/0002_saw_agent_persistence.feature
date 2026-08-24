Feature: saw-agent persistent OpenClaw state
  The Cirrus cloud-init package can attach persistent disks to saw-agent so
  OpenShell and OpenClaw state survive VM recreation.

  Rule: While saw-agent is provisioned, Cirrus cloud-init shall attach state and asset PVCs without mounting them directly.

    Scenario: saw-agent receives persistent state and asset disks
      Given the committed Server saw-agent manifest references the saw-agent persistence PVCs
      When saw-agent starts from cloud-init
      Then saw-agent receives separate disks for service state and assets

  Rule: If a saw-agent persistent disk is blank, then the agent playbook shall format it exactly once.

    Scenario: Blank saw-agent persistent disks are initialized safely
      Given saw-agent receives unformatted persistent disks
      When agent provisioning prepares persistent storage
      Then saw-agent formats each blank disk before mounting it

  Rule: While agent provisioning runs, the agent playbook shall mount OpenShell and OpenClaw state before service setup.

    Scenario: OpenShell service state is written to persistent storage
      Given saw-agent receives the persistent state disk
      When agent provisioning prepares OpenShell configuration
      Then saw-agent stores OpenShell configuration and gateway state on the persistent disk

    Scenario: OpenClaw sandbox storage is written to persistent storage
      Given saw-agent receives the persistent asset disk
      When agent provisioning prepares OpenClaw sandbox storage
      Then saw-agent stores rootless container storage on the persistent disk

  Rule: While saw-agent is recreated, the agent playbook shall regenerate user service units on the fresh root disk.

    Scenario: User service units do not start before binaries are installed
      Given saw-agent has persisted OpenShell state
      When saw-agent starts with a fresh root disk
      Then saw-agent regenerates user service units during agent provisioning

  Rule: While saw-agent uses persistent sandbox storage, the agent playbook shall preserve an existing Ready OpenClaw sandbox.

    Scenario: Existing Ready OpenClaw sandbox survives reprovisioning
      Given saw-agent already has a Ready OpenClaw sandbox
      When agent provisioning runs again
      Then the existing sandbox is reused instead of deleted

  Rule: While saw-agent is aligned with the OpenClaw SAW demo, the agent configuration shall use openclaw-saw as the OpenClaw sandbox name.

    Scenario: Demo-compatible OpenClaw sandbox identity is configured
      Given saw-agent is deployed for the OpenClaw SAW demo
      When agent provisioning creates the OpenClaw sandbox
      Then the sandbox identity is openclaw-saw

  Rule: While saw-agent persists OpenClaw identity assets, the agent playbook shall mount the OpenClaw home from the state PVC into the sandbox.

    Scenario: OpenClaw workspace files survive sandbox replacement
      Given saw-agent has a state PVC for OpenClaw home files
      When the OpenClaw sandbox is created
      Then the sandbox receives a writable host bind mount at the OpenClaw home path

  Rule: If saw-agent has a persisted non-Ready OpenClaw sandbox, then the agent playbook shall replace it before creating the gateway sandbox.

    Scenario: Existing Error OpenClaw sandbox is replaced
      Given saw-agent has an Error OpenClaw sandbox
      When agent provisioning prepares the gateway sandbox
      Then the existing sandbox is deleted before sandbox creation

    Scenario: Existing Error OpenClaw sandbox is replaced after reboot
      Given saw-agent has a persisted Error OpenClaw sandbox after guest reboot
      When agent provisioning prepares the gateway sandbox
      Then the existing sandbox is retried until it can be deleted and recreated

  Rule: While saw-agent exposes OpenClaw through the authenticated userport, the agent playbook shall bind the external proxy to all guest interfaces and reserve the raw OpenClaw forward for localhost.

    Scenario: Authenticated userport remains reachable after VM recreation
      Given saw-agent exposes OpenClaw through an authenticated userport
      When agent provisioning configures OpenClaw network listeners
      Then oauth2-proxy accepts userport traffic on every guest interface
      And the raw OpenClaw forward remains available only on localhost

  Rule: If the base image does not provide optional Python packaging tools, then the role dispatcher shall avoid installing them on saw-agent.

    Scenario: saw-agent provisioning does not require python3-pip
      Given saw-agent starts from the Cirrus RHEL base image
      When role dispatch provisioning installs shared agent packages
      Then provisioning avoids the unavailable python3-pip package

  Rule: If OpenClaw user services fail to start, then the agent playbook shall report sandbox and unit diagnostics before failing.

    Scenario: OpenClaw sandbox start failure includes actionable diagnostics
      Given saw-agent has generated OpenClaw user service units
      When an OpenClaw user service fails to start
      Then provisioning reports the sandbox list and recent user service journal


  Rule: While OpenClaw runtime config is generated, the agent playbook shall persist the live-good OpenAI completions provider and trusted-proxy settings.

    Scenario: Runtime config matches the live validated gateway setup
      Given saw-agent is deployed for the OpenClaw SAW demo
      When agent provisioning writes OpenClaw runtime configuration
      Then OpenClaw uses the OpenAI completions provider through the sandbox inference route
      And OpenClaw trusts the authenticated route proxy for Alice

  Rule: While OpenClaw user services are being started, the agent playbook shall verify actual service activity before failing provisioning.

    Scenario: Active OpenClaw services are accepted after noisy start output
      Given OpenClaw user services have been requested to start
      When the service manager reports their actual activity
      Then provisioning continues if the required services are active
