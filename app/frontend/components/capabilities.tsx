import SectionLabel from './section_label'

/** The `capabilities` prop of the consent and Agents pages: `Agents::Capabilities.to_prop`. */
export type Capabilities = {
  can: string[]
  cannot: string[]
  webmcp_note: string
}

function Lines({ label, lines }: { label: string; lines: string[] }) {
  return (
    <div>
      <SectionLabel as="p" className="mb-2 mt-4">
        {label}
      </SectionLabel>
      <ul className="border-t border-line text-[15px] leading-normal text-fg">
        {lines.map((line) => (
          <li key={line} className="border-b border-line py-3">
            {line}
          </li>
        ))}
      </ul>
    </div>
  )
}

/** What an agent can and can't do, in the server's words. The two lists read at the same weight: the limits are as loud as the grants. */
export default function CapabilityLists({ capabilities, className = '' }: { capabilities: Capabilities; className?: string }) {
  return (
    <div className={className}>
      <Lines label="It can" lines={capabilities.can} />
      <Lines label="It can’t" lines={capabilities.cannot} />
    </div>
  )
}
