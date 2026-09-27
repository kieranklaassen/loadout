import { fireEvent, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { heroData } from '../../test/home_fixtures'
import Hero from './hero'

const reduceMotion = (reduce: boolean) =>
  vi.stubGlobal('matchMedia', (query: string) => ({ matches: reduce && query.includes('prefers-reduced-motion'), media: query, addEventListener() {}, removeEventListener() {} }))

afterEach(() => vi.unstubAllGlobals())

const animation = (container: HTMLElement) => container.querySelector('.hero') as HTMLElement

describe('Hero', () => {
  it('is decorative: the picture is hidden from assistive tech and the caption says what it shows', () => {
    const { container } = render(<Hero hero={heroData()} />)

    expect(animation(container)).toHaveAttribute('aria-hidden', 'true')
    expect(screen.getByText('6 people ranked 30 picks · Last update Sep 19', { exact: false })).toBeVisible()
    expect(screen.getByRole('figure')).toBeInTheDocument()
  })

  it('draws one board per kind with its ranked tools and models, and only what exists', () => {
    const { container } = render(<Hero hero={heroData()} />)

    const boards = container.querySelectorAll('.hero-board')
    expect(boards).toHaveLength(3)
    expect(boards[0]).toHaveTextContent('Coding')
    expect(boards[0]).toHaveTextContent('1st')
    expect(boards[0]).toHaveTextContent('Claude Code')
    expect(boards[0]).toHaveTextContent('Claude Opus 5.5')
    expect(boards[0]).toHaveTextContent('2nd')
    expect(boards[0]).toHaveTextContent('No model')
    expect(boards[0].querySelectorAll('.hero-pick')).toHaveLength(2)
    expect(boards[1].querySelectorAll('.hero-pick')).toHaveLength(1)
  })

  it('plays by default and the Pause button stops it', () => {
    reduceMotion(false)
    const { container } = render(<Hero hero={heroData()} />)

    expect(animation(container)).toHaveAttribute('data-playing', 'true')
    fireEvent.click(screen.getByRole('button', { name: 'Pause animation' }))

    expect(animation(container)).toHaveAttribute('data-playing', 'false')
    expect(screen.getByRole('button', { name: 'Play animation' })).toBeInTheDocument()
  })

  it('is paused by default under reduced motion and the Play button starts it', () => {
    reduceMotion(true)
    const { container } = render(<Hero hero={heroData()} />)

    expect(animation(container)).toHaveAttribute('data-playing', 'false')
    fireEvent.click(screen.getByRole('button', { name: 'Play animation' }))

    expect(animation(container)).toHaveAttribute('data-playing', 'true')
  })

  it('has nothing to pause with a single board', () => {
    const hero = heroData({ boards: [heroData().boards[0]], people: 1, picks: 1 })
    const { container } = render(<Hero hero={hero} />)

    expect(screen.queryByRole('button')).not.toBeInTheDocument()
    expect(animation(container)).toHaveAttribute('data-playing', 'false')
    expect(screen.getByText('1 person ranked 1 pick', { exact: false })).toBeInTheDocument()
  })

  it('tells the stylesheet how many boards there are, for the loop length', () => {
    const two = heroData().boards.slice(0, 2)
    const { container } = render(<Hero hero={heroData({ boards: two })} />)

    expect(animation(container)).toHaveAttribute('data-boards', '2')
  })

  it('renders nothing when there are no boards', () => {
    const { container } = render(<Hero hero={heroData({ boards: [] })} />)

    expect(container).toBeEmptyDOMElement()
  })
})
