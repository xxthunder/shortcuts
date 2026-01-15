# Feature Specification: WSL Manager

**Feature Branch**: `001-wsl-manager`
**Created**: 2026-01-12
**Status**: Draft
**Input**: User description: "We want to implement a WSL Manager that allows us to install, clone, configure and terminate WSL distributions. This was already started and you can find implementation in tools/pslib/wsl\ and user stories in docs/stories\"

## Clarifications

### Session 2026-01-12

- Q: When a long-running operation fails partway through (e.g., Docker installation downloads 300MB then network fails), what should happen? → A: Fail immediately, prompt user to retry, and leave system in safe state
- Q: When cloning a distribution that has a configured user account and Docker installed, what should be preserved in the clone? → A: Everything - filesystem, users, Docker, systemd, all configurations
- Q: Should the tool maintain operational logs beyond what's displayed to console, and if so, where? → A: Use PowerShell transcript capability - users enable via Start-Transcript when needed
- Q: Should the tool warn users about the security implications of NOPASSWD sudo during user account creation? → A: Display brief warning once during user creation about NOPASSWD implications
- Q: Should operations proceed on running distributions, or should the system require stopping them first? → A: Require distributions to be stopped - fail with clear message and termination command

## User Scenarios & Testing *(mandatory)*

### User Story 1 - List and View WSL Distributions (Priority: P1)

A developer wants to see which WSL distributions are installed on their system so they can decide which one to work with or manage.

**Why this priority**: This is the foundation for all other operations - users need to know what distributions exist before they can manage them. It's the simplest, most frequently used operation.

**Independent Test**: Can be fully tested by running the list command on a system with multiple WSL distributions and verifying all installed distributions are displayed correctly.

**Acceptance Scenarios**:

1. **Given** WSL is installed with 2 distributions (Debian and Ubuntu), **When** user runs list command, **Then** both distributions are displayed with clear numbering
2. **Given** WSL is installed but no distributions exist, **When** user runs list command, **Then** a helpful message indicates no distributions are found
3. **Given** WSL is not installed, **When** user runs list command, **Then** an error message explains WSL needs to be installed first

---

### User Story 2 - Create New WSL Distribution (Priority: P2)

A developer wants to create a new WSL distribution from any available Linux distribution so they can have a fresh environment for a project.

**Why this priority**: Creating distributions is a fundamental operation needed before any configuration. It enables developers to set up new environments without manual installation steps.

**Independent Test**: Can be tested by creating a distribution with a valid name (e.g., Debian, Ubuntu-22.04) and verifying it appears in the list of installed distributions and can be started successfully.

**Acceptance Scenarios**:

1. **Given** WSL is installed and Debian is available online, **When** user creates a Debian distribution, **Then** distribution is installed successfully and appears in the list
2. **Given** WSL is installed, **When** user attempts to create a distribution with an invalid name, **Then** available distributions are shown with a clear error message
3. **Given** WSL is installed, **When** user creates a distribution that already exists, **Then** an error message indicates the distribution name is already in use
4. **Given** WSL is installed, **When** user creates any Ubuntu LTS version (20.04, 22.04, 24.04), **Then** the specific version is installed correctly
5. **Given** distribution is created, **When** user checks its status, **Then** distribution is ready to use without requiring initial user setup

---

### User Story 3 - Clone Existing Distribution (Priority: P3)

A developer wants to clone an existing WSL distribution with a custom name so they can create project-specific environments based on a configured template.

**Why this priority**: Cloning enables efficient environment replication - after setting up one distribution, developers can clone it for multiple projects. This saves configuration time but is less critical than initial creation.

**Independent Test**: Can be tested by cloning an existing distribution (e.g., Debian to MyProject), verifying the clone appears in the list, and confirming changes to the clone don't affect the source.

**Acceptance Scenarios**:

1. **Given** a Debian distribution exists, **When** user clones it with name "MyProject", **Then** a new independent distribution named MyProject is created
2. **Given** multiple distributions exist, **When** user clones Ubuntu-22.04 to ProjectX, **Then** ProjectX is created as an exact copy of Ubuntu-22.04 including all filesystem contents, user accounts, Docker installations, systemd configurations, and installed packages
3. **Given** a distribution exists, **When** user attempts to clone it with a name that already exists, **Then** an error message indicates the target name is unavailable
4. **Given** a distribution is cloned, **When** files are modified in the clone, **Then** the source distribution remains unchanged
5. **Given** a distribution with configured user and Docker is cloned, **When** the clone is started, **Then** the user account and Docker installation are immediately available without reconfiguration
6. **Given** a distribution is running, **When** user attempts to clone it, **Then** error message directs user to stop distribution with `wsl --terminate <name>` command

---

### User Story 4 - Remove WSL Distribution (Priority: P4)

A developer wants to remove unused WSL distributions so they can free disk space and keep their system organized.

**Why this priority**: Removal is important for cleanup but less urgent than creation and management. Users typically remove distributions after they're done with a project.

**Independent Test**: Can be tested by removing a distribution, verifying it no longer appears in the list, and confirming the disk space is reclaimed.

**Acceptance Scenarios**:

1. **Given** a distribution named "TestProject" exists, **When** user removes it with confirmation, **Then** the distribution is unregistered and no longer appears in the list
2. **Given** multiple distributions exist, **When** user selects one to remove by number or name, **Then** only the selected distribution is removed
3. **Given** a distribution exists, **When** user attempts to remove it in non-interactive mode, **Then** confirmation can be skipped with appropriate flag
4. **Given** a distribution doesn't exist, **When** user attempts to remove it, **Then** an error message indicates the distribution wasn't found
5. **Given** a distribution is running, **When** user attempts to remove it, **Then** error message directs user to stop distribution with `wsl --terminate <name>` command

---

### User Story 5 - Terminate Running Distribution (Priority: P5)

A developer wants to stop a running WSL distribution so they can perform operations that require the distribution to be stopped (clone, remove, update) or free system resources.

**Why this priority**: Terminating distributions is a necessary operation for other management tasks (as established in clarifications - FR-030) and for resource management. While important, it's less frequently needed than core creation/removal operations.

**Independent Test**: Can be tested by starting a distribution, terminating it via the manager, and verifying the distribution is no longer running and can be started again.

**Acceptance Scenarios**:

1. **Given** a distribution is running, **When** user runs terminate command, **Then** the distribution is stopped immediately and no longer appears in running process list
2. **Given** multiple distributions are running, **When** user terminates one by name or number, **Then** only the selected distribution is stopped
3. **Given** a distribution is not running, **When** user attempts to terminate it, **Then** an informational message indicates the distribution is already stopped
4. **Given** a distribution is terminated, **When** user checks its status, **Then** distribution shows as stopped and can be started again
5. **Given** interactive mode is active, **When** user selects terminate command, **Then** list of running distributions is shown for selection
6. **Given** no distributions are running, **When** user runs terminate command, **Then** a message indicates no running distributions to terminate

---

### User Story 6 - Update Distribution Packages (Priority: P6)

A developer wants to update packages in their Debian or Ubuntu WSL distributions so their development environment has the latest security patches and package versions.

**Why this priority**: Package updates maintain system health but aren't required for initial setup. Users can perform updates when needed rather than as part of initial configuration.

**Independent Test**: Can be tested by updating a Debian/Ubuntu distribution and verifying all packages are upgraded successfully through the standard apt workflow.

**Acceptance Scenarios**:

1. **Given** a Debian distribution exists, **When** user runs update command, **Then** apt update and upgrade are executed successfully
2. **Given** an Ubuntu distribution exists, **When** user runs update command, **Then** packages are updated and orphaned packages are removed
3. **Given** an Arch Linux distribution exists, **When** user attempts to update it, **Then** an error message explains only Debian/Ubuntu distributions are supported
4. **Given** no distributions exist, **When** user runs update command, **Then** a warning message is displayed
5. **Given** a distribution needs updates, **When** update completes, **Then** apt cache is cleaned to free disk space
6. **Given** a distribution is running, **When** user attempts to update it, **Then** error message directs user to stop distribution with `wsl --terminate <name>` command

---

### User Story 7 - Setup User Account (Priority: P7)

A developer wants to create a default user account with sudo privileges in their WSL distribution so they can work with proper permissions without using the root account.

**Why this priority**: User setup improves security and follows best practices, but distributions can be used with root initially. This is a configuration step rather than a core management function.

**Independent Test**: Can be tested by creating a user account, verifying it has sudo access without password prompts, and confirming it's set as the default user after distribution restart.

**Acceptance Scenarios**:

1. **Given** a fresh distribution exists, **When** user creates account "developer" with password, **Then** user is created with home directory and sudo privileges
2. **Given** a distribution exists, **When** user creates an account, **Then** the account is added to the sudo group with NOPASSWD configured
3. **Given** a distribution exists, **When** user creates an account, **Then** the account is set as default in /etc/wsl.conf
4. **Given** a user account is created, **When** distribution is restarted, **Then** the new user is logged in by default
5. **Given** username validation, **When** user provides invalid username (uppercase, special chars, >32 chars), **Then** clear error message explains requirements
6. **Given** a user already exists, **When** attempting to create it again, **Then** an error message indicates the user exists
7. **Given** user account creation begins, **When** NOPASSWD sudo will be configured, **Then** a brief warning is displayed about security implications for development environments

---

### User Story 8 - Setup Docker Engine (Priority: P8)

> **Implementation Status**: Docker Engine installation is **functionally complete and working** in the current codebase. This user story's acceptance scenarios are satisfied.
>
> **Phase 2 Refactoring**: Refactoring the Docker installation from PowerShell-calling-bash-oneliners to a single clean bash script is **ACTIVE** and scheduled for implementation (see plan.md Phase 2).
>
> **Impact**: Users can install Docker successfully today. The refactoring is an internal code quality improvement that ensures long-term maintainability.

A developer wants to install Docker Engine in their WSL distribution with a single command so they can run containers for development without manual Docker configuration.

**Why this priority**: Docker setup is an advanced configuration for specific workflows. Not all developers need Docker, making this the lowest priority core feature.

**Independent Test**: Can be tested by installing Docker in a Ubuntu/Debian distribution, verifying the Docker service is running, and successfully running a hello-world container.

**Acceptance Scenarios**:

1. **Given** an Ubuntu-22.04 distribution with systemd enabled, **When** user runs setup-docker, **Then** Docker Engine is installed and service is running
2. **Given** a distribution exists, **When** Docker installation completes, **Then** the default user is added to docker group
3. **Given** Docker is installed, **When** user restarts the distribution and runs docker commands, **Then** commands work without sudo
4. **Given** a WSL1 distribution, **When** user attempts Docker setup, **Then** error message explains WSL2 is required
5. **Given** a distribution without systemd, **When** user attempts Docker setup, **Then** error message provides systemd configuration instructions
6. **Given** a distribution without default user, **When** user attempts Docker setup, **Then** error message directs to setup-user command
7. **Given** Docker is already installed, **When** user runs setup-docker, **Then** error message shows current version and suggests verification steps
8. **Given** an Arch Linux distribution, **When** user attempts Docker setup, **Then** error message lists supported distributions (Debian/Ubuntu)

---

### User Story 9 - Interactive Mode (Priority: P1)

A developer wants to run the WSL manager without remembering command syntax so they can easily discover and execute available commands through an interactive menu.

**Why this priority**: Interactive mode provides the best user experience and is the default entry point. It enables discoverability without documentation and reduces cognitive load.

**Independent Test**: Can be tested by launching without arguments, verifying the menu displays available commands and distributions, and successfully executing operations through menu selections.

**Acceptance Scenarios**:

1. **Given** WSL is installed with distributions, **When** user runs without arguments, **Then** interactive menu displays with list of distributions and available commands
2. **Given** interactive mode is active, **When** user selects a command by letter, **Then** the command executes and menu returns
3. **Given** interactive mode is active, **When** user selects exit or presses Ctrl+C, **Then** the application exits cleanly
4. **Given** running in CI environment, **When** user runs without arguments, **Then** a helpful message explains interactive mode is unavailable
5. **Given** WSL is not installed, **When** user launches interactive mode, **Then** error message explains WSL is required
6. **Given** user selects a command, **When** distributions are listed, **Then** selection by number or name is supported

### Edge Cases

- What happens when WSL is not installed on the system?
- How does the system handle extremely long distribution names or invalid characters?
- What happens when cloning a distribution and disk space is insufficient?
- How does the system handle interrupted operations (e.g., network failure during creation)? → System fails immediately, leaves system in safe state, prompts user to retry
- What happens when attempting to update a distribution while it's running? → System requires distribution to be stopped first, fails with message directing user to run `wsl --terminate <name>`
- How does the system handle non-English Windows systems (localized WSL output)?
- What happens when user permissions prevent distribution management?
- How does the system behave when /etc/wsl.conf has malformed content?
- What happens during Docker installation if network is unavailable? → System fails immediately with clear error, prompts user to retry when network available
- How does the system handle systemd not starting properly after configuration?
- What happens when terminating a distribution that has active processes or unsaved work?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST detect if WSL is installed before attempting any operations
- **FR-002**: System MUST list all installed WSL distributions with clear numbering
- **FR-003**: System MUST support creating distributions from any distribution available via `wsl --list --online`
- **FR-004**: System MUST support cloning any installed distribution to a new custom name
- **FR-005**: System MUST verify distribution names before creation or cloning operations
- **FR-006**: System MUST support removing distributions with user confirmation
- **FR-007**: System MUST allow confirmation prompts to be skipped in non-interactive environments
- **FR-008**: System MUST update packages in Debian and Ubuntu distributions using apt
- **FR-009**: System MUST detect distribution type before attempting updates
- **FR-010**: System MUST create user accounts with home directories and sudo privileges
- **FR-011**: System MUST validate usernames according to Linux standards (lowercase, max 32 chars, specific allowed characters)
- **FR-012**: System MUST configure created users with NOPASSWD sudo access
- **FR-013**: System MUST set created users as default in /etc/wsl.conf
- **FR-014**: System MUST install Docker Engine with all required components in Ubuntu/Debian distributions
- **FR-015**: System MUST validate prerequisites before Docker installation (WSL2, systemd, default user)
- **FR-016**: System MUST verify Docker installation with comprehensive checks (version, service status, hello-world test)
- **FR-017**: System MUST provide interactive menu mode when no command is specified
- **FR-018**: System MUST support both interactive and command-line interfaces
- **FR-019**: System MUST detect CI/test environments and adjust behavior accordingly
- **FR-020**: System MUST handle localized WSL output (different system languages)
- **FR-021**: System MUST provide clear error messages for all failure scenarios
- **FR-022**: System MUST support distribution selection by number or name in interactive mode
- **FR-023**: System MUST display executed commands for transparency and debugging
- **FR-024**: System MUST clean up temporary files after clone operations
- **FR-025**: System MUST add users to docker group during Docker setup
- **FR-026**: System MUST fail immediately on operation errors, leave system in safe state, and prompt user to retry rather than attempting automatic recovery
- **FR-027**: System MUST preserve all configurations when cloning distributions, including filesystem contents, user accounts, Docker installations, systemd settings, and installed packages
- **FR-028**: System MUST rely on PowerShell's built-in transcript capability for operational logging rather than maintaining separate log files (users enable logging via Start-Transcript when needed)
- **FR-029**: System MUST display a brief warning about NOPASSWD sudo security implications when creating user accounts in development environments
- **FR-030**: System MUST require distributions to be stopped before performing update, clone, or remove operations, failing with clear message and termination command if distribution is running
- **FR-031**: System MUST support terminating running WSL distributions on demand
- **FR-032**: System MUST detect whether a distribution is running before attempting termination
- **FR-033**: System MUST provide informative feedback when attempting to terminate an already-stopped distribution

### Key Entities

- **WSL Distribution**: A Linux distribution instance managed by WSL, with attributes like name, type (Debian/Ubuntu/etc.), version (WSL1/WSL2), installation status, and running state (running/stopped)
- **User Account**: A Linux user within a distribution, with username, password, sudo privileges, group memberships, and default status
- **Docker Installation**: Docker Engine configuration within a distribution, with service status, version information, and user access permissions
- **Distribution Type**: Classification of distributions by package manager family (debian, ubuntu, arch, rhel, unknown)
- **Installation Configuration**: WSL distribution settings in /etc/wsl.conf, including default user and systemd configuration

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can discover all available commands through interactive mode without consulting documentation
- **SC-002**: Users can create any WSL distribution available from Microsoft in under 5 minutes (network dependent)
- **SC-003**: Users can clone an existing distribution to a new name in under 3 minutes for typical 5GB distributions
- **SC-004**: All operations provide clear success or failure feedback with actionable next steps
- **SC-005**: Error messages guide users to resolution in 90% of failure scenarios without external documentation
- **SC-006**: Docker setup completes successfully on clean Ubuntu/Debian distributions in under 10 minutes
- **SC-007**: User account creation completes in under 30 seconds with immediate confirmation
- **SC-008**: Package updates complete successfully on Debian/Ubuntu distributions without manual intervention
- **SC-009**: System handles non-English Windows environments without failures (localized WSL output)
- **SC-010**: All destructive operations (remove) require explicit confirmation in interactive mode
- **SC-011**: Tool works correctly in both PowerShell 5.1 and PowerShell 7.x environments
- **SC-012**: 95% of users successfully complete their intended operation on first attempt without errors
- **SC-013**: Users can terminate a running distribution in under 5 seconds with immediate confirmation

## Assumptions

- Users have Windows 10 version 2004 or later (required for WSL2)
- Users have administrator privileges or ability to run WSL commands
- Internet connectivity is available for creating distributions and installing Docker
- Default installation locations are acceptable (no custom paths required initially)
- Users running Docker setup understand systemd requirement and can configure it if needed
- English language is used for all user-facing messages and prompts
- WSL feature is already enabled in Windows (if not, system provides installation guidance)
- Users accept default apt repositories for package updates
- PowerShell execution policy allows running scripts
- Sufficient disk space is available for distribution operations (users receive errors if insufficient, no pre-validation)
- Users who need persistent operational logs will enable PowerShell transcript capability (Start-Transcript) before running commands
