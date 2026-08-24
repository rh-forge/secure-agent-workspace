Feature: saw-integ persistent integration state
  The Cirrus cloud-init package can attach a persistent disk to saw-integ so
  integration secrets survive VM recreation while code remains reproducible.

  Rule: While saw-integ is provisioned, Cirrus cloud-init shall attach the saw-integ-persist PVC without mounting it directly.

    Scenario: saw-integ receives the persistent integration disk
      Given the committed Server saw-integ manifest references the saw-integ-persist PVC
      When saw-integ starts from cloud-init
      Then saw-integ receives the persistent disk for integration provisioning

  Rule: If the persistent integration disk is blank, then the integration playbook shall format it exactly once.

    Scenario: Blank persistent disk is initialized safely
      Given saw-integ receives an unformatted persistent disk
      When integration provisioning prepares persistent storage
      Then saw-integ formats the disk before mounting it

  Rule: While integration provisioning runs, the integration playbook shall mount persistent integration directories before writing proxy configuration.

    Scenario: Integration configuration is written to persistent storage
      Given saw-integ receives the persistent integration disk
      When integration provisioning prepares proxy configuration
      Then saw-integ stores integration configuration on the persistent disk

  Rule: While integration provisioning runs, the integration playbook shall preserve an existing provider key.

    Scenario: Existing provider key survives reprovisioning
      Given saw-integ already has a non-empty provider key
      When integration provisioning runs again
      Then the existing provider key remains unchanged
