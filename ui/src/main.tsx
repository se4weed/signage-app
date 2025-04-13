import React from "react";
import ReactDOM from "react-dom/client";
import { App } from "./App.tsx";
//import "./index.css";

if (!/^\/control/.test(location.pathname)) document.body.style.margin = "0";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
