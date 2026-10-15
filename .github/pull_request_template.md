## What this does

<!-- A sentence or two on what changes for the user, and why. -->

## Changes

<!-- The main pieces, e.g. models, pages, jobs. Skip what's obvious from the title. -->

-

## Screenshots

<!-- For anything visible: before and after, desktop and phone. Delete this section if there's nothing to show. -->

| Before | After |
| --- | --- |
|  |  |

## How to try it

<!-- Steps to see it locally, e.g. which page to open and what data you need (sandbox Plaid or the demo user). -->

1.

## Checklist

- [ ] `bundle exec rspec` passes, with specs for the new behavior
- [ ] `bin/rubocop` is clean
- [ ] Checked in the browser, on desktop and phone width
- [ ] Migrations only add (no dropping or rewriting data that's in production), and are safe to run on deploy
- [ ] No secrets committed (keys go in `.env` or Rails credentials)
- [ ] Plaid calls work in sandbox, and nothing assumes sandbox in production
- [ ] No big new memory costs (the app has to fit in Northflank's 500 MB)

## Notes for deploy

<!-- Anything to do on Northflank: new environment variables, one-off commands, or what to watch after deploying. Write "None" if there's nothing. -->

None
