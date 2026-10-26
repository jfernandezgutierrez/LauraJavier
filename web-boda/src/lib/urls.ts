// Keep links inside the deployment directory, including GitHub project Pages.
export const appBase = import.meta.env.BASE_URL
export const appUrl = new URL(appBase, location.origin).href
