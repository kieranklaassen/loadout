import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import RiffrecProvider from './riffrec_provider'

describe('RiffrecProvider', () => {
  it('renders children unchanged when capture is disabled', () => {
    render(
      <RiffrecProvider enabled={false} config={null}>
        <span>child content</span>
      </RiffrecProvider>,
    )

    expect(screen.getByText('child content')).toBeInTheDocument()
  })

  it('renders children and mounts nothing that throws when enabled with a stub config', () => {
    render(
      <RiffrecProvider
        enabled={true}
        config={{ endpoint: 'https://riffrec.example.test', public_key: 'pk_placeholder' }}
      >
        <span>child content</span>
      </RiffrecProvider>,
    )

    expect(screen.getByText('child content')).toBeInTheDocument()
  })
})
