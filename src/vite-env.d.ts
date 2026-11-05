/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_ARCADIA_FACTORY?: string
  readonly VITE_ARCADIA_VAULT?: string
  readonly VITE_ARCADIA_DEPLOY_BLOCK?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
