---
name: create-storybook
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Create Storybook stories when the user asks, a new component needs stable visual or
  interaction coverage, or the requested UI change explicitly requires story coverage. Do not
  trigger for every UI edit or before every commit.
---

# Create Storybook

Create stories for React components following project conventions.

## REQUIRED: Tags and Interaction Tests

Every story MUST have:
1. **Tags** - For filtering and categorization
2. **Interaction tests (play function)** - For interactive components

### Interaction Tests Must Test BEHAVIOR, Not Just Display

**NG**: Only checking if element is displayed
```tsx
// BAD: Just checking display
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)
  expect(canvas.getByRole('button')).toBeInTheDocument() // Not enough!
}
```

**OK**: Testing actual user behavior and results
```tsx
// GOOD: Testing form submission flow
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)

  // 1. Fill form fields
  await userEvent.type(canvas.getByLabelText(/name/i), 'Test')

  // 2. Submit form
  await userEvent.click(canvas.getByRole('button', { name: /submit/i }))

  // 3. Verify result (success message, redirect, state change)
  await waitFor(() => {
    expect(canvas.getByText(/saved/i)).toBeInTheDocument()
  })
}
```

### What to Test
- **Forms**: Input → Submit → Success/Error states
- **Buttons**: Click → Action result (dialog opens, data updates)
- **Tabs/Views**: Click → Content switches correctly
- **Dialogs**: Open → Interact → Close
- **Validation**: Invalid input → Error message displayed

## Workflow

After creating/updating a story:

```bash
# 1. Start Storybook (background or separate terminal)
pnpm exec turbo run storybook --filter=<app>

# 2. Wait for Storybook to be ready (port 6006)

# 3. Run tests
pnpm exec turbo run test-storybook --filter=<app>

# 4. Run specific tags only
pnpm exec turbo run test-storybook --filter=<app> -- --includeTags=<tag>
```

## File Naming

```
component-name.stories.tsx  # kebab-case, same directory as component
```

## Basic Template (with REQUIRED tags)

```tsx
import type { Meta, StoryObj } from '@storybook/react'
import { expect, userEvent, waitFor, within } from '@storybook/test'
import { ComponentName } from './component-name'

const meta = {
  title: 'Category/ComponentName',
  component: ComponentName,
  parameters: {
    layout: 'centered', // or 'fullscreen'
  },
  tags: ['autodocs', 'feature-name'],  // REQUIRED: always add tags
} satisfies Meta<typeof ComponentName>

export default meta
type Story = StoryObj<typeof ComponentName>

export const Default: Story = {
  args: {
    // component props
  },
}

// REQUIRED for interactive components: add play function
export const WithInteraction: Story = {
  args: { /* ... */ },
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)

    // Wait for render
    await waitFor(() => {
      expect(canvas.getByRole('button')).toBeInTheDocument()
    })

    // User action
    await userEvent.click(canvas.getByRole('button', { name: /submit/i }))

    // Verify result
    await waitFor(() => {
      expect(canvas.getByText('Success')).toBeInTheDocument()
    }, { timeout: 5000 })
  },
}
```

## Title Conventions

| App | Pattern | Example |
|-----|---------|---------|
| library | `V1Beta/ComponentName` | `V1Beta/RepositoryUi` |
| tachyon | `Features/ComponentName` | `Features/CodingJobList` |
| bakuure-ui | `Features/ComponentName` | `Features/ClientForm` |
| packages/ui | `UI/ComponentName` | `UI/AppBar` |

## Tags (REQUIRED)

Always include tags for filtering:

```tsx
// Base tags
tags: ['autodocs']                    // Auto-generate docs

// Feature tags (pick relevant ones)
tags: ['autodocs', 'form']            // Form components
tags: ['autodocs', 'dialog']          // Dialog/modal components
tags: ['autodocs', 'table']           // Table/data display
tags: ['autodocs', 'navigation']      // Nav components
tags: ['autodocs', 'mcp']             // MCP-related
tags: ['autodocs', 'auth']            // Auth-related
```

## Interaction Test Patterns

### Form Submission
```tsx
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)

  // Fill form
  await userEvent.type(canvas.getByLabelText(/name/i), 'Test User')
  await userEvent.type(canvas.getByLabelText(/email/i), 'test@example.com')

  // Submit
  await userEvent.click(canvas.getByRole('button', { name: /submit/i }))

  // Verify
  await waitFor(() => {
    expect(canvas.getByText(/success/i)).toBeInTheDocument()
  })
}
```

### Tab/View Switching
```tsx
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)

  // Click tab
  await userEvent.click(canvas.getByRole('tab', { name: /settings/i }))

  // Verify content changed
  await waitFor(() => {
    expect(canvas.getByText(/settings content/i)).toBeInTheDocument()
  })
}
```

### Dialog Open/Close
```tsx
play: async ({ canvasElement }) => {
  const canvas = within(canvasElement)

  // Open dialog
  await userEvent.click(canvas.getByRole('button', { name: /open/i }))

  // Verify dialog
  await waitFor(() => {
    expect(canvas.getByRole('dialog')).toBeInTheDocument()
  })

  // Close dialog
  await userEvent.click(canvas.getByRole('button', { name: /close/i }))

  // Verify closed
  await waitFor(() => {
    expect(canvas.queryByRole('dialog')).not.toBeInTheDocument()
  })
}
```

## With Layout/Decorator

```tsx
import V1BetaLayout from '../layout.storybook'

const meta = {
  decorators: [
    Story => (
      <V1BetaLayout params={{ org: 'demo-org', repo: 'demo-repo' }}>
        <Story />
      </V1BetaLayout>
    ),
  ],
  parameters: {
    layout: 'fullscreen',
    nextjs: {
      navigation: {
        segments: [['org', 'demo-org'], ['repo', 'demo-repo']],
        pathname: '/v1beta/demo-org/demo-repo',
      },
    },
  },
}
```

## GraphQL Mocking

```tsx
import { MockedProvider } from '@apollo/client/testing'
import { GetDataDocument } from '@/gen/graphql'

const mocks = [
  {
    request: { query: GetDataDocument, variables: { id: '123' } },
    result: { data: { getData: { id: '123', name: 'Test' } } },
  },
]

const meta = {
  decorators: [
    Story => (
      <MockedProvider mocks={mocks} addTypename={false}>
        <Story />
      </MockedProvider>
    ),
  ],
}
```

## Date Mocking (VRT)

Use fixed dates to avoid snapshot differences:
```tsx
args: {
  createdAt: '2024-04-01T00:00:00Z',
  updatedAt: '2024-04-05T00:00:00Z',
}
```

## Checklist (MUST complete)

- [ ] Tags added (autodocs + feature tag)
- [ ] Interaction tests for all interactive elements
- [ ] Storybook started and test-storybook passes
- [ ] File named `{component}.stories.tsx` (kebab-case)
- [ ] Title follows app convention
- [ ] Default story with typical props
- [ ] Edge case stories (empty, error, loading)
- [ ] Fixed dates for time-dependent data
- [ ] Accessibility: use roles over test-ids
