# User Stories - Substitution

This document outlines the requirements for **Substitution**, a decentralized social network built on the Matrix protocol.

## Epic 1: Onboarding & Identity
*"I want to own my identity and choose where my data lives."*

*   **US-1.1:** As a **new user**, I want to **choose my homeserver** during login, so that I can decide who hosts my data (e.g., `matrix.org` or a self-hosted instance).
*   **US-1.2:** As a **user**, I want to **log in with my existing Matrix credentials**, so that I don't have to create a new account specifically for this app.
*   **US-1.3:** As a **user**, I want to **stay logged in** across sessions, so I don't have to enter my password every time I open the app.
*   **US-1.4:** As a **user**, I want to **edit my profile (display name and avatar)**, so that others can recognize me.

## Epic 2: Discovery & Subscriptions
*"I want to find and curate the content I see."*

*   **US-2.1:** As a **user**, I want to **search for public rooms** (feeds) across the federation, so that I can discover new communities and content creators.
*   **US-2.2:** As a **user**, I want to **follow (join) a room**, so that its posts appear in my main feed.
*   **US-2.3:** As a **user**, I want to **unfollow (leave) a room**, so that I can remove content I'm no longer interested in.
*   **US-2.4:** As a **user**, I want to **view a specific room's feed** in isolation, so I can binge-read content from a specific creator or topic.

## Epic 3: The Feed (Consumption)
*"I want a seamless, modern reading experience."*

*   **US-3.1:** As a **user**, I want to **view a unified timeline** of posts from all my followed rooms, sorted chronologically.
*   **US-3.2:** As a **user**, I want to **scroll infinitely** to load older posts, so I have an uninterrupted browsing experience.
*   **US-3.3:** As a **user**, I want to **see rich media previews** (images, videos) directly in the feed without clicking links.
*   **US-3.4:** As a **user**, I want the app to **cache content offline**, so I can read posts even when I have a spotty internet connection.

## Epic 4: Engagement & Interaction
*"I want to interact with the community."*

*   **US-4.1:** As a **user**, I want to **react to a post with emojis**, so I can express agreement or appreciation without typing.
*   **US-4.2:** As a **user**, I want to **see how many others have reacted** to a post, so I can gauge community sentiment.
*   **US-4.3:** As a **user**, I want to **reply to a post**, creating a threaded conversation.
*   **US-4.4:** As a **user**, I want to **tap on a user's avatar** to see their profile or other posts.

## Epic 5: Content Creation
*"I want to share my thoughts and art."*

*   **US-5.1:** As a **creator**, I want to **compose text posts** with basic formatting (bold, italic, lists), so my content is easy to read.
*   **US-5.2:** As a **creator**, I want to **upload images and videos** from my device, so I can share visual art.
*   **US-5.3:** As a **creator**, I want to **create a new room (feed)**, so I can start my own blog or community topic.
*   **US-5.4:** As a **creator**, I want to **set permissions** on my room (e.g., who can post vs. who can only read), so I can maintain it as a blog (one-to-many) or a community topic.

## Epic 6: Privacy & Settings
*"I want control over the app experience."*

*   **US-6.1:** As a **user**, I want to **clear my local cache**, so I can free up space on my device.
*   **US-6.2:** As a **user**, I want to **verify the encryption keys** of users I communicate with (if E2EE is enabled), so I know my messages are secure.
*   **US-6.3:** As a **user**, I want to **switch between light and dark mode**, so the app is comfortable to use in any lighting.
