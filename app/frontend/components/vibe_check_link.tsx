/** The link-out to a launched model's Vibe Check on Every's sign-in-gated site. The server has already checked the URL. */
export default function VibeCheckLink({ url, modelName, className = '' }: { url: string; modelName: string; className?: string }) {
  return (
    <a href={url} target="_blank" rel="noopener noreferrer" aria-label={`Vibe Check for ${modelName}`} className={`text-link text-sm ${className}`.trim()}>
      Vibe Check <span aria-hidden="true">↗</span>
    </a>
  )
}
