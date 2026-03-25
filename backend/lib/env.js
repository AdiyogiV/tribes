import { defineString } from "firebase-functions/params";

export const appEnv = defineString("APP_ENV", {
    default: "production",
});
