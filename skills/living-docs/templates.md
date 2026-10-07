# Living doc skeletons

Copy only the skeleton you need. Delete any section with nothing true to say; never leave a heading
over an empty paragraph. A project overrides a skeleton by placing its own copy at
`specs/.templates/product.md`, `business.md` or `tech.md`.

## product.md

```markdown
# <Project>: product

<One paragraph: what it is, for whom, and the problem it removes.>

## Who it is for
- <Primary user>: <what they are trying to get done>

## The problem
<What hurts without it, in the user's words.>

## What it does
- <Capability>: <the outcome for the user>

## What it will not do
- <Non-goal>: <why, in one line>

## Key journeys
1. <Journey name>: <start> → <steps> → <outcome>. Spec: specs/<NNN-name>/

Last verified: <YYYY-MM-DD> against <commit or source>
```

## business.md

```markdown
# <Project>: business

## Model
<Who pays, for what, and how often. Pricing, if any.>

## Market
<Who else solves this, and why someone picks this instead.>

## Constraints
- <Legal, compliance, contractual or budget limit>: <what it forces>

## Metrics that matter
- <Metric>: <current value or target> (<where it is measured>)

Last verified: <YYYY-MM-DD> against <commit or source>
```

## tech.md

```markdown
# <Project>: tech

## Stack
| Layer | Choice | Why |
| --- | --- | --- |

## Architecture
<The parts, what each owns, how they talk. A diagram when prose cannot carry it.>

## Data
<Where state lives, who owns each store, what must never be lost.>

## Integrations
- <Service>: <what for> · <how it fails and what happens then>

## Environments
| Name | URL or host | Deploys from | Notes |
| --- | --- | --- | --- |

## Conventions
<Only what a newcomer would get wrong. Link the lint and format configs, never restate them.>

Last verified: <YYYY-MM-DD> against <commit or source>
```
