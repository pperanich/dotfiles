# Method notes

## Comparable review prompts

**UX Workflow Check** follows a person's intent from entry through a return visit and asks what evidence supports each gap. Its stopping rule explores successive personas. This runbook uses the project's documented roles and makes coverage visible so a reviewer can tell whose work was examined. [Original skill](https://github.com/sergiobuilds/ux-workflow-check/blob/main/SKILL.md)

**UX Audit** asks for a location, evidence, severity, and confidence for each finding across 16 review dimensions. The distinction between seeing a rendered state and reading its implementation is especially useful on projects where only one platform can run locally. Here each finding attaches to the decision it affects. [Original skill](https://github.com/paulunemoon/ux-audit-skill/blob/main/SKILL.md)

## Reviewing the work and the interface

- Derive goals from accounts of what people do. Turn them into realistic tasks phrased without clues about which control to use. This makes it possible to find a task the current navigation never represents. [GOV.UK on learning user needs](https://www.gov.uk/service-manual/user-research/start-by-learning-user-needs) · [Nielsen Norman Group on task scenarios](https://www.nngroup.com/articles/task-scenarios-usability-testing/)
- The cognitive walkthrough asks whether a person can recognize the next action, connect it to their goal, and see that it worked. Following a task through confirmation catches failures that a tour of individual screens misses. [Wharton, Rieman, Lewis, and Polson, _The Cognitive Walkthrough Method_](https://www.colorado.edu/ics/sites/default/files/attached-files/93-07.pdf)
- The UK Government Analysis Function asks dashboard designers which decisions people will make with the data. This runbook applies that question to the most prominent content on any screen. [Guidance on building and managing dashboards](https://analysisfunction.civilservice.gov.uk/policy-store/data-visualisation-building-and-managing-dashboards/)
- Use platform guidance to investigate a concrete obstacle, such as keyboard focus moving away from the item being edited. [Apple on macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos) · [Apple on iOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-ios) · [W3C on focus order](https://www.w3.org/WAI/WCAG22/Understanding/focus-order.html)

## Writing the agent instructions

The prompt uses an explicit sequence, a worked comparison, and an observable completion condition. The inspection tools and level of detail can vary with the project. These choices follow guidance on specifying the desired outcome, illustrating a difficult output, and testing a skill on representative work. [OpenAI's reasoning-model prompting guidance](https://developers.openai.com/api/docs/guides/reasoning-best-practices) · [Anthropic's skill-authoring guidance](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

Anthropic's research agents split a broad question into independent assignments with explicit boundaries and return evidence to a lead. This audit uses that pattern twice. Scouts first establish the workflows, then inspect the UI using the same map so the lead can compare observations at a handoff. [Lead agent prompt](https://github.com/anthropics/claude-cookbooks/blob/main/patterns/agents/prompts/research_lead_agent.md) · [Multi-agent research system](https://www.anthropic.com/research/multi-agent-research-system)
