import { initializeApp } from "firebase/app";
import {
  getFirestore,
  collection,
  query,
  where,
  addDoc,
  onSnapshot,
  or,
  orderBy,
  limit,
} from "firebase/firestore";
import OpenAI from "openai";

const openai = new OpenAI({
  apiKey: import.meta.env.VITE_OPENAI_KEY,
  dangerouslyAllowBrowser: true,
});

const app = initializeApp({
  apiKey: import.meta.env.VITE_FS_API_KEY,
  authDomain: import.meta.env.VITE_FS_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FS_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FS_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FS_MSG_SENDER_ID,
  appId: import.meta.env.VITE_FS_APP_ID,
  measurementId: import.meta.env.VITE_FS_MEASUREMENT_ID,
});
const db = getFirestore(app);

type Chat = {
  text: string;
  from: string;
  to: string;
  timestampMs: number;
};

const CHAT_COLLECTION: string = "chats";

const AI = {
  id: "deeplayr_ai",
  knowledge:
    "You're an AI agent (DeepLayr AI), you know about the concept of restaking, and SUI blockchain.",

  getChats(from: string, callback: (chats: Chat[]) => void) {
    try {
      const chatsRef = collection(db, CHAT_COLLECTION);
      const chatsQuery = query(
        chatsRef,
        or(where("from", "==", from), where("to", "==", from)),
        orderBy("timestampMs", "desc"),
        limit(50)
      );
      onSnapshot(chatsQuery, async (snapshot) => {
        const chats = snapshot.docs.map((chat) => chat.data());
        callback(chats as any);
      });
    } catch (error) {}
  },

  async chat(from: string, text: string): Promise<void> {
    try {
      const in_chat: Chat = {
        text,
        from,
        to: this.id,
        timestampMs: Date.now(),
      };

      await addDoc(collection(db, CHAT_COLLECTION), in_chat);

      const completion = await openai.chat.completions.create({
        messages: [
          { role: "user", content: text },
          { role: "system", content: this.knowledge },
        ],
        model: "gpt-4o-mini",
      });

      if (
        completion.choices.length == 0 ||
        !completion.choices[0].message.content
      ) {
        const err_chat: Chat = {
          text: "Failed to respond.",
          from: this.id,
          to: from,
          timestampMs: Date.now(),
        };
        await addDoc(collection(db, CHAT_COLLECTION), err_chat);
        return;
      }

      const out_chat: Chat = {
        text: completion.choices[0].message.content,
        from: this.id,
        to: from,
        timestampMs: Date.now(),
      };
      await addDoc(collection(db, CHAT_COLLECTION), out_chat);
    } catch (error) {
      console.log(error);
    }
  },
};

export { type Chat, AI };
