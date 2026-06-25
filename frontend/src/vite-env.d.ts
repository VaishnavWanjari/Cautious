/// <reference types="vite/client" />

declare const __IS_DEV__: boolean;

interface Window {
  scheduler?: {
    backendBaseUrl: () => Promise<string>;
  };
}
