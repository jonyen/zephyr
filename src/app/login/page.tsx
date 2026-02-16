"use client";
import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const { login, register } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      if (isRegister) await register(email, password);
      else await login(email, password);
      router.push("/");
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "An error occurred");
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-stone-50">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm space-y-4 rounded-xl bg-white p-8 shadow-lg"
      >
        <h1 className="text-2xl font-bold text-center">Zephyr</h1>
        <p className="text-center text-stone-500 text-sm">
          {isRegister ? "Create account" : "Sign in"}
        </p>
        {error && (
          <p className="text-red-500 text-sm text-center">{error}</p>
        )}
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          className="w-full rounded-lg border px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500"
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          className="w-full rounded-lg border px-4 py-2 outline-none focus:ring-2 focus:ring-blue-500"
          required
          minLength={6}
        />
        <button
          type="submit"
          className="w-full rounded-lg bg-blue-600 py-2 text-white font-medium hover:bg-blue-700"
        >
          {isRegister ? "Register" : "Sign In"}
        </button>
        <button
          type="button"
          onClick={() => setIsRegister(!isRegister)}
          className="w-full text-sm text-blue-600"
        >
          {isRegister
            ? "Already have an account? Sign in"
            : "Need an account? Register"}
        </button>
      </form>
    </div>
  );
}
