# Speaker Notes

---

## Slide 1 — Title Slide

Opening: Good morning everyone. Today I'll be talking about Account Factory for Terraform, also called AFT.
Point 1: I'll cover what AFT is and how it works at a high level.
Point 2: How accounts are provisioned.
Point 3: Some of the customisations I made while working on the Evoke project.

---

## Slide 2 — Agenda

Opening: Here's the agenda for today.
Point 1: Quick introduction to AFT, then the architecture and how account provisioning works.
Point 2: The custom work we delivered.
Point 3: Issues I ran into, and finish with questions.

---

## Slide 3 — What is AFT?

Opening: AFT stands for Account Factory for Terraform.
Point 1: It lets us create AWS accounts using Terraform, Git, and pipelines.
Point 2: We define the account in HCL, push it to Git, and the pipeline builds it.
Point 3: Each account gets the same baseline setup, and we can place accounts into different OUs and apply customisations for different teams.
Point 4: This makes the process more consistent and less manual.

---

## Slide 4 — Control Tower Prerequisite

Opening: AFT depends on Control Tower, so Control Tower has to come first.
Point 1: It creates the management, Log Archive, and Audit accounts.
Point 2: It sets up the core guardrails and OU structure.
Point 3: When AFT creates a new account, Control Tower automatically brings it into logging and security monitoring.

---

## Slide 5 — Three-Account Architecture (SVG)

Opening: Here we have the three-account architecture.
Point 1: The Management account is where AFT runs and where the orchestration happens.
Point 2: The Log Archive account collects logs, and the Audit account handles security services.
Point 3: Any new account created through AFT fits into this wider Control Tower setup, so logging and security are already built around it.

---

## Slide 6 — The Four-Phase Journey (SVG)

Opening: The key point on this slide is that phases one to three are setup work you do once.
Point 1: After that, you commit the account definition to Git, the pipeline runs, and the account is created.
Point 2: The heavy lifting is upfront, but once it is in place, provisioning becomes repeatable and much less manual.

---

## Slide 7 — Pre-flight Check

Opening: Before deploying AFT, we make sure the foundation is ready.
Point 1: That includes Control Tower, the account IDs, the Git setup, IAM Identity Centre, and the Terraform backend.
Point 2: Once those are all in place, we can move ahead with the deployment.
Point 3: This step helps avoid deployment issues later by making sure the key dependencies are already in place.

---

## Slide 8 — Architecture: What AFT Deploys

Opening: AFT deploys three main frameworks in the Management account.
Point 1: The request framework picks up the change from Git, validates it, and tracks the request.
Point 2: The provisioning framework runs the account creation flow and uses Service Catalog through Control Tower.
Point 3: The customisation framework applies the Terraform from the customisation repos to the new account.
Summary: AFT receives the request, creates the account, and then applies the customisations.

---

## Slide 9 — Where AFT Operates (SVG)

Opening: AFT lives in the Management account.
Point 1: It runs everything from there, then uses cross-account roles to make changes in the target accounts.
Point 2: Management is central, but the setup is applied across many accounts.
Point 3: This avoids duplicating the AFT setup in every account.

---

## Slide 10 — Provisioning Flow (SVG)

Opening: The flow is simple.
Point 1: Commit to Git, validate the request, create the account, then apply the customisations.
Point 2: Once that finishes, the account is ready.
Point 3: From the engineer's point of view, the main action is just committing the HCL, and AFT handles the rest.

---

## Slide 11 — How an Account Gets Provisioned

Opening: Now I'll walk through how an account gets provisioned through AFT.
Point 1: First, the four GitHub repositories and how they are structured.
Point 2: Then the account request file, which is the HCL that triggers provisioning.
Point 3: The pipeline execution, from source through to apply.
Point 4: The provisioned account in AWS Organisations, and the resources and customisations that get deployed.

---

## Slide 12 — 1. GitHub Repositories

Opening: This slide shows the four AFT repos.
Point 1: Each repo has its own job, depending on whether the change is for a new account, all accounts, a specific account, or the provisioning stage.
Point 2: Once we push the change, the pipeline picks it up automatically.
Point 3: This repo split keeps the setup organised and makes it clear where each type of change should go.

---

## Slide 13 — 2. Account Request: The HCL File

Opening: This file is the actual account request.
Point 1: It tells AFT what the account should be called, which OU it belongs to, who owns it, and what tags to apply.
Point 2: Once we add this file, the provisioning process can start.
Point 3: This makes the request process clear, repeatable, and easy to review through Git.

---

## Slide 14 — 2b. Optional Fields

Opening: These are some optional fields you can add to the account request file.
Point 1: The change management fields record who requested the account and why, useful for audit.
Point 2: The account customisations name links the account to a specific set of customisations.
Point 3: The custom fields section lets you pass extra metadata that your pipelines or logic can use later.
Summary: Optional, but very useful when you want more control, traceability, or custom behaviour.

---

## Slide 15 — 3. Pipeline Execution

Opening: When we push to the account request repo, the pipeline starts automatically.
Point 1: CodePipeline detects the change, then Terraform Plan shows what is going to be created.
Point 2: There is a manual approval step. Once approved, Terraform Apply runs and creates the account through Service Catalog.
Point 3: The customisation stage applies the global and account-specific configuration.
Point 4: The whole process usually takes around 30 to 40 minutes.

---

## Slide 16 — 4. Provisioned Account

Opening: Once the pipeline completes, the new account is fully set up.
Point 1: It appears in AWS Organizations under the correct OU, with SSO access configured through IAM Identity Centre.
Point 2: The account is connected to central logging through Log Archive, and GuardDuty and Security Hub are active.
Point 3: The account is tagged based on the values from the HCL file.
Summary: The account is not just created, it is already placed into the right structure with the right access, logging, and security controls.

---

## Slide 17 — 5. Deployed Resources: Global Customisations

Opening: This slide shows an example of the global customisations.
Point 1: These settings are applied automatically to every new account.
Point 2: Every account gets GuardDuty enabled, Security Hub enabled, and central logging configured.
Point 3: This becomes the standard baseline. Instead of setting these up manually, AFT applies them automatically.

---

## Slide 18 — 5. Deployed Resources: Account Customisations

Opening: This slide shows the account customisations.
Point 1: Unlike the global customisations, these are applied only to specific accounts on top of the baseline.
Point 2: This is controlled from the account request file, for example with account_customizations_name.
Point 3: A sandbox account might get its own S3 bucket, IAM role, and VPC, while another account gets a different setup.
Summary: Each account gets the global baseline, plus its own account-specific resources.

---

## Slide 19 — What We Delivered at Evoke

Opening: This slide summarises what we delivered at Evoke.
Point 1: Ira did the AFT research and documentation. Shoutout to her on that.
Point 2: I added pipeline approval gates, so customisation changes follow a plan, approve, and apply process.
Point 3: I also built a quota increment service using Lambda to automatically request quota increases across AWS regions.

---

## Slide 20 — Pipeline Before: Default AFT (SVG)

Opening: This is the default AFT pipeline before our changes.
Point 1: A source change would go straight into global and account customisations, with Terraform apply running directly.
Point 2: No plan review and no approval step, which meant less visibility and more risk.
Point 3: This is why we introduced approval gates into the pipeline.

---

## Slide 21 — Pipeline Without Approval Gates (Screenshot)

Opening: This is the real thing in the console.
Point 1: Three stages, no plan, no approval.
Point 2: Whatever you push gets applied.

---

## Slide 22 — Pipeline After: With Approval Gates (SVG)

Opening: This is the updated pipeline with approval gates.
Point 1: We added a plan stage and a manual approval step before each apply.
Point 2: This applies to both global and account customisations.
Point 3: That gave us much better visibility and control before changes were executed.

---

## Slide 23 — Pipeline With Approval Gates (Screenshot)

Opening: This is the pipeline after the approval gates were added.
Point 1: It now follows a plan, approve, and apply flow for both global and account customisations.
Point 2: This gives us more control before changes are executed.

---

## Slide 24 — Quota Increment Service (SVG)

Opening: This is the quota increment service.
Point 1: A Lambda function checks quotas across the target regions and submits increase requests where needed.
Point 2: It monitors the status and sends updates to Slack.
Point 3: This replaced a manual process with an automated one, especially useful across different regions and services at the same time.

---

## Slide 25 — Quota Increment: Pipeline Output

Opening: This is the output of the quota service.
Point 1: It shows the current quota and the target quota.
Point 2: It confirms that requests were submitted in each region where needed.

---

## Slide 26 — Quota Increment: Approval Screen

Opening: This screen shows the quota requests in AWS.
Point 1: It confirms the automation submitted them successfully and they are now waiting for approval.
Point 2: We can see both sides of the process, the pipeline output and the actual requests appearing in AWS.

---

## Slide 27 — Troubleshooting: GitHub Connection Error

Opening: This issue happened because the GitHub connection created by AFT starts in a pending state.
Point 1: Until it is manually approved, the pipelines cannot pull from GitHub.
Point 2: The fix was to go into Developer Tools, open the pending connection, and complete the GitHub approval.

---

## Slide 28 — Troubleshooting: Pipeline Failures (Screenshot)

Opening: This is where we first saw the problem.
Point 1: The pipelines were failing.
Point 2: We had to investigate the execution details to find the cause.

---

## Slide 29 — Troubleshooting: Error Detail (Screenshot)

Opening: This slide shows the root cause clearly.
Point 1: The GitHub connection was not available, so the pipeline could not pull the source.
Point 2: Once we confirmed that, the fix was straightforward.

---

## Slide 30 — Issue 1: CodeStar Connection Fix (Screenshot)

Opening: This shows the fix.
Point 1: The GitHub connection was still pending.
Point 2: We completed the authorisation in Developer Tools. After that, the pipeline worked.

---

## Slide 31 — Issue 1: Update Pending Connection (Screenshot)

Opening: This is the final step of the fix.
Point 1: Click Update pending connection.
Point 2: Connect it to your GitHub account, then re-run the pipeline.

---

## Slide 32 — Troubleshooting: OU Not Enrolled

Opening: This error happened because the OU in the request was not valid for Control Tower.
Point 1: We found it in Service Catalog, then fixed the OU value in the HCL file.

---

## Slide 33 — Troubleshooting: Service Catalog Error (Screenshot)

Opening: This is where we found the error in Service Catalog.
Point 1: One account request had failed, so we opened it and traced the issue back to the OU value.
Point 2: Service Catalog was the main place we used to troubleshoot account request failures.

---

## Slide 34 — Troubleshooting: Provisioned Products (Screenshot)

Opening: This error showed us the real problem.
Point 1: The OU in the request was not valid for Control Tower, so we fixed the OU value and reran it.
Point 2: The key lesson was to check Provisioned Products when account creation fails.

---

## Slide 35 — Troubleshooting: SSM Parameter Must Point to Your Repo

Opening: The customisations pipelines needed the SSM parameter to point to our repo.
Point 1: Without that, they could pull the wrong framework code.
Point 2: We updated the SSM value before running them.
Point 3: Not all AFT pipelines depend on the framework in the same way.

---

## Slide 36 — Troubleshooting: Why SSM Matters

Opening: This slide shows why SSM mattered.
Point 1: The customisations pipeline pulls framework scripts like creds.sh and metrics.py from the repo linked in SSM.
Point 2: If SSM points to the default AWS repo, our custom MODE logic is missing, so the approval stages do not work.
Point 3: Once SSM points to our repo, the pipeline uses the correct framework and the approval flow works.

---

## Slide 37 — Issue 4: Service Catalog Portfolio Access

Opening: AFT could not provision accounts until it had access to the Control Tower Service Catalog portfolio.
Point 1: The AWSAFTExecution role needed to be added to the portfolio.
Point 2: Once added, AFT could provision accounts through Service Catalog.

---

## Slide 38 — Issue 4: Service Catalog Portfolio (Screenshot)

Opening: This is the portfolio AFT needed.
Point 1: We used this screen to give the AWSAFTExecution role access so account provisioning could work.

---

## Slide 39 — Issue 4: Add AWSAFTExecution Role (Screenshot)

Opening: This is the step to add the role.
Point 1: Search for AWSAFTExecution under the Roles tab.
Point 2: Check the box and click Add access.

---

## Slide 40 — Issue 4: AWSAFTExecution Role Added (Screenshot)

Opening: This shows the fix.
Point 1: We added the AWSAFTExecution role to the portfolio.
Point 2: That gave AFT the access it needed to provision accounts.

---

## Slide 41 — Let's Walk Through the Repos

Opening: Now let's walk through the AFT repositories.
Point 1: The account request repo is where you add a new account, one .tf file per account.
Point 2: The global customisations repo is the security baseline, applied to every account.
Point 3: The account customisations repo is for anything specific to one account, like extra S3 buckets or VPCs.
Point 4: The account provisioning customisations repo runs before the baseline, used for early setup.

---

## Slide 42 — Any Questions?

Opening: That's it, any questions?
