/** Public site / Roblox OAuth portal links */
export const site = {
  appName: "RBLX Clothing Maker",
  tagline: "RBLX Clothing Maker for Roblox Creators",
  siteUrl: "https://hun.social",
  description:
    "RBLX Clothing Maker is a mobile creator companion for generating, previewing, and managing Roblox UGC clothing assets through a secure backend integration.",
  oauthDescription:
    "RBLX Clothing Maker is a mobile creator companion that lets Roblox users securely connect their account to preview avatars, manage creator assets, and perform approved UGC workflows through a server-side integration.",
  playStoreUrl:
    "https://play.google.com/store/apps/details?id=com.rblxclothingmaker.app",
  privacyUrl: "https://hun.social/privacy",
  termsUrl: "https://hun.social/terms",
  supportEmail: "support@hun.social",
  lastUpdated: "July 30, 2026",
  permissions: [
    {
      slug: "openid",
      scope: "openid",
      title: "OpenID",
      summary: "Enables Single Sign-On so the app can verify your Roblox identity.",
    },
    {
      slug: "profile",
      scope: "profile",
      title: "Profile",
      summary: "Allows reading your Roblox profile information (username, display name, avatar).",
    },
    {
      slug: "asset-read",
      scope: "asset:read",
      title: "Asset Read",
      summary: "Allows viewing information about your Roblox assets when you approve creator workflows.",
    },
    {
      slug: "asset-write",
      scope: "asset:write",
      title: "Asset Write",
      summary: "Allows uploading and updating assets to Roblox through approved server-side workflows.",
    },
  ],
} as const;
