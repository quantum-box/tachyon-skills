---
name: implement-component
description: >-
  Applies only to work in the quantum-box/tachyon-apps repository.
  Proactively implement React component when UI implementation is needed. Use this skill when:
  (1) New page or screen needs to be created, (2) UI component implementation is required, (3)
  Form or interactive element is being added, (4) Task involves frontend implementation with
  Next.js App Router. Uses Server/Client component patterns with GraphQL integration.
---

# Implement React Component

Next.js App RouterとReactパターンに従ってコンポーネントを実装する。

## Directory Structure

```
apps/tachyon/src/app/v1beta/[tenant_id]/{feature}/
├── page.tsx                       # Server Component (page)
├── components/
│   ├── {component-name}.tsx       # kebab-case
│   ├── {component-name}.stories.tsx
│   └── {component-name}-graphql.tsx
├── queries/
│   └── {feature}.graphql          # Separate GraphQL queries
└── actions.ts                     # Server Actions
```

**Naming**: All kebab-case (`feature-flag-list.tsx`, `ab-test-reports.tsx`)

## Server Component (Page)

```tsx
import { authWithCheck } from '@/app/auth'
import { getGraphqlSdk } from '@/lib/tachyon-api'
import { V1BetaSidebarHeader } from '@/components/v1beta-sidebar-header'
import { Breadcrumb, BreadcrumbList, BreadcrumbItem, BreadcrumbLink, BreadcrumbPage, BreadcrumbSeparator } from '@/components/ui/breadcrumb'
import { ClientComponent } from './components/client-component'

export default async function {Feature}Page({
  params: { tenant_id },
}: {
  params: { tenant_id: string }
}) {
  const session = await authWithCheck(tenant_id)
  const sdk = await getGraphqlSdk(session.accessToken, tenant_id)
  const { data } = await sdk.{Query}({ operatorId: tenant_id })

  return (
    <V1BetaSidebarHeader
      breadcrumbs={
        <Breadcrumb>
          <BreadcrumbList>
            <BreadcrumbItem>
              <BreadcrumbLink href={`/v1beta/${tenant_id}`}>ホーム</BreadcrumbLink>
            </BreadcrumbItem>
            <BreadcrumbSeparator />
            <BreadcrumbItem>
              <BreadcrumbPage>{Feature}名</BreadcrumbPage>
            </BreadcrumbItem>
          </BreadcrumbList>
        </Breadcrumb>
      }
    >
      <div className='container mx-auto py-10'>
        <ClientComponent data={data} tenantId={tenant_id} />
      </div>
    </V1BetaSidebarHeader>
  )
}
```

## Client Component

```tsx
'use client'

import { useState } from 'react'
import { useQuery, useMutation } from '@apollo/client'
import { useQueryState } from 'nuqs'
import { {QueryDocument}, {MutationDocument} } from '@/gen/graphql'
import { Button } from '@/components/ui/button'
import { useToast } from '@/hooks/use-toast'

interface Props {
  tenantId: string
  initialData?: SomeType
}

export function {Component}({ tenantId, initialData }: Props) {
  const [searchQuery, setSearchQuery] = useState('')
  const [tab, setTab] = useQueryState('tab', { defaultValue: 'overview' })

  const { data, loading, error, refetch } = useQuery({QueryDocument}, {
    variables: { filter: { search: searchQuery } },
  })

  const [mutation] = useMutation({MutationDocument})
  const { toast } = useToast()

  const handleAction = async () => {
    try {
      await mutation({ variables: { ... } })
      toast({ title: '成功', description: '処理が完了しました' })
      refetch()
    } catch (error) {
      toast({ title: 'エラー', description: 'エラーが発生しました', variant: 'destructive' })
    }
  }

  if (loading) return <div>Loading...</div>
  if (error) return <div>Error: {error.message}</div>

  return (
    <div className='space-y-4'>
      {/* Content */}
    </div>
  )
}
```

## Storybook

```tsx
import type { Meta, StoryObj } from '@storybook/react'
import { MockedProvider } from '@apollo/client/testing'
import { within, expect } from '@storybook/test'
import { {Component} } from './{component-name}'
import { {QueryDocument} } from '@/gen/graphql'

const mocks = [
  {
    request: {
      query: {QueryDocument},
      variables: { filter: { search: undefined } },
    },
    result: { data: mockData },
  },
]

const meta = {
  title: '{Feature}/{Component}',
  tags: ['autodocs', '{feature}'],
  component: {Component},
  decorators: [
    (Story, context) => (
      <MockedProvider mocks={context.parameters?.apolloMocks || mocks} addTypename={false}>
        <Story />
      </MockedProvider>
    ),
  ],
  args: { tenantId: '<tenant-id>' },
} satisfies Meta<typeof {Component}>

export default meta
type Story = StoryObj<typeof meta>

export const Default: Story = {
  play: async ({ canvasElement }) => {
    const canvas = within(canvasElement)
    await canvas.findByRole('table', {}, { timeout: 5000 })
  },
}
```

## Important Rules

1. **`'use client'`**: Place at top of client-only components
2. **GraphQL in `.graphql` files**: Import from `@/gen/graphql`
3. **kebab-case naming**: `feature-flag-list.tsx`
4. **V1BetaSidebarHeader wrapper**: Wrap entire page
5. **`authWithCheck()` in Server Component**: Execute authentication
6. **Breadcrumb via props**: Pass through props
7. **Storybook tags**: `pnpm exec turbo run test-storybook --filter=<app> -- --includeTags=<tag>`
