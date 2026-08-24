Feature: Forge UI side-by-side preview
  The Cirrus deployment can expose the Forge UI beside the current OpenClaw UI
  before the relay and OpenClaw replacement work is enabled.

  Rule: While the Forge UI preview is enabled, the deployment shall expose only the static Forge UI container.

    Scenario: Static Forge UI is routable without relay dependencies
      Given the committed Forge UI manifest is applied to OpenShift
      When the Forge UI route is created
      Then the route serves the static Forge UI container
      And relay, injector, and OpenClaw gateway dependencies are not required

  Rule: While the Forge UI preview is enabled, the deployment shall preserve the existing OpenClaw authenticated route.

    Scenario: Forge UI route is side-by-side with OpenClaw
      Given saw-agent already exposes OpenClaw through the authenticated userport
      When the Forge UI preview is deployed
      Then the OpenClaw userport route remains unchanged
      And the Forge UI uses a separate route host

  Rule: While namespace permissions prevent Deployment creation, saw-agent provisioning shall expose the static Forge UI from inside the agent VM.

    Scenario: Forge UI is hosted through the saw-agent service
      Given saw-agent can expose named service ports through Cirrus
      When saw-agent provisioning starts the Forge UI preview
      Then the static Forge UI listens on a dedicated saw-agent port
      And the Forge UI route targets the saw-agent service instead of a Deployment
