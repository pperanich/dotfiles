---
name: workflow-ui-audit
description: Audit an existing macOS, web, or iOS app with parallel subagents. Map user workflows, then compare what people need to know or do with what the UI shows at each step. Use when reviewing task flows, deciding what belongs on a screen, or investigating why an interface feels unhelpful.
---

# Audit the UI against user workflows

Review the project named in the request, or the current project if none is named. Honor any narrower scope. Return the review in the requested format, or in the conversation by default. Exercise state-changing steps with test data or within the user's explicit authorization.

## Understand the project, then send out scouts

As lead, read enough project material to brief another person on what the product does, who uses it, which outcomes matter, and which platforms are in scope. Cite the sources and flag assumptions. Start delegating as soon as you can name distinct questions worth investigating.

Launch read-only subagents together within the host's available capacity. Give each primary workflow an owner from trigger to outcome. Choose additional assignments where information needs, navigation, accessibility, or recovery raise distinct questions. In a staffing app, one scout might trace how a coordinator fills a vacancy while another follows the volunteer who receives the offer. Assign one of them the handoff where the volunteer's reply becomes visible to the coordinator.

Give each scout a fresh context with the shared brief, its question and boundaries, and sources of user need. The first assignment is a cited task map. When the sources are separable, save screenshots and UI traces for the second assignment. If the interface is the only source, ask which needs can be inferred from it and label them accordingly.

The lead owns dispatch. Scouts return evidence and flag adjacent questions for the lead to assign. Use economical models for bounded evidence gathering and a stronger model for design critique. Reserve top-tier subagents for an explicit user request. If delegation is unavailable, run the assignments yourself and disclose that in the review.

## Establish the work before judging the screens

Start with evidence of why people use the product. Look for the user's brief, research, support reports, product docs, and acceptance scenarios already available to the project. Cite the source of each important workflow. A support report documents one person's experience. A spec establishes intended behavior. When the UI or source code is your only clue to a need, label the need as a hypothesis and say what would confirm it.

Name each workflow in the user's words. Record who starts it, what prompts them, what they already know, and how they can tell they are done. Include work outside the app when the evidence describes it, such as a dispatcher calling someone for a fact the schedule omits. Write a realistic task someone could attempt without being told which controls to use. Sometimes the whole task is getting a trustworthy answer.

Map the decisions in task order. At each one, write the question the person needs answered, the minimum facts they need **at that moment**, and the action or outcome those facts enable. Do this before recording what occupies the screen. For a project-wide review, inventory the workflows and cover the primary ones and those where a mistake is costly. Give the basis for that priority. Account for each in-scope workflow and platform as exercised, inspected from artifacts, or unexamined.

Collect the scouts' task maps and any overlooked roles or steps. Merge them into a shared map, keeping disputed needs visible. Once the map is ready, send it to each walkthrough scout in a new assignment with the starting scenario and the UI evidence or environment to inspect. Launch these walkthroughs in parallel, resuming the original scouts or dividing the work by platform where the experiences differ.

## Walk the current product

Try each scenario from its normal entry point in the running app when available. Use realistic records that force a choice, such as two items with different deadlines. Follow the choice through to its visible result. Include a return visit, interruption, empty state, failure, or handoff when it could change the answer or the ability to finish.

Use independent sessions and test records for concurrent walkthroughs. If scouts share one window, simulator, or mutable record, give one scout control while the others inspect recordings, tests, or source.

At each decision, compare the two sides in one row. In this fictional example, the coordinator's morning checklist calls for filling the earliest vacancy. The monthly planning brief asks for the overall staffing rate.

| Workflow and step                                       | Question and information needed now                                                           | What the UI puts first               | Where the answer or action is                                                    | Consequence                                                             |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ------------------------------------ | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Coordinator opening the web app before tomorrow's shift | Which shift should I fill first? I need the start time and the number of people still needed. | Home shows “92% staffed this month.” | Schedule → Open shifts already lists “08:00, one opening” with an Assign action. | The coordinator can fill the shift, but must leave Home to identify it. |

For actual rows, cite the platform, route or view, state, and a locator someone can check. A short interaction trace, screenshot, test case, or file and line can serve. Say which you used. Screenshots establish what was visible in the captured state. Source can establish which data a view receives. Reserve claims about a completed interaction for behavior you ran or have a recording or trace of. Mark inaccessible states as unverified. Attribute user behavior or frequency to user evidence.

Check the platform details that could change the outcome of this particular task.

| Platform | Questions to try in the walkthrough                                                                                                             |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| macOS    | Can someone act on the selected item from the keyboard or menu? After switching or resizing windows, is it clear which item the action affects? |
| Web      | Can someone reach the same answer by keyboard or at a narrow width? What context survives a direct link, Back, or refresh?                      |
| iOS      | Are the deciding facts and action reachable by touch and readable at larger text sizes? What does the person return to after an interruption?   |

Compare shared tasks across supported platforms using the same starting facts. Account for the job each platform is meant to support. If the product promises a handoff, trace what the next device or person actually receives.

## Decide what belongs at each step

For each prominent item, ask what question it answers here and who relies on it. Locate each needed fact. It might be visible, buried in details, shown after the choice, or unavailable altogether. Even a visible number can answer the wrong question. Check its time range, freshness, or level of detail when that changes the decision. Check plausible alternate paths before declaring information missing. If the answer would require data the product might not have, name that dependency.

Recommend the smallest change that closes the gap. Say what should appear first, what can move to details or another workflow, and what already earns its place. In the shift example, surface the next open shift and its existing Assign action on the coordinator's Home. The monthly figure still answers a planning question. A concrete check is whether the coordinator can identify the earliest unfilled shift and begin assigning it from Home when an earlier shift is already full.

Then review visual hierarchy, copy, and styling against the project's design language. Explain what a change makes easier to find, read, or operate. A focus or contrast problem that prevents completion takes the severity of a blocked task. Keep optional polish brief.

## Deliver the review

Collect each scout's decision rows, evidence locators, and gaps in coverage. If a scout cannot finish, reassign its question or check the evidence yourself and record any remaining gap. Join observations at handoffs and recheck high-impact or conflicting claims against the original evidence for the same role, platform, and state. Count a trace once even when several scouts cite it.

Deliver one workflow map, the decision comparisons, and findings in priority order. Link findings back to workflow steps and use stable IDs such as `W1` and `F1` when there are several. Reserve findings for mismatches supported by evidence. For each, give the consequence, the smallest proposed change, and an observable pass condition using the original scenario. Group repeated instances of the same problem. Put unverified concerns under open questions with the smallest check that would settle each one.

Rank by consequence first, distinguishing a blocked or wrong outcome from avoidable work and cosmetic polish. Use reach or frequency when evidence supports it. State confidence separately from impact. Close with the most important change to make, the user question that would decide it, or the existing design choice worth preserving when the workflow already works.

For the original review prompts and the research behind this method, see the [method notes](references/method.md).
