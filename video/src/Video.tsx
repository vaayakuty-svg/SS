import "@fontsource/fredoka/600.css";
import "@fontsource/fredoka/700.css";
import "@fontsource/vt323/400.css";
import "@fontsource/jetbrains-mono/500.css";
import { ThreeCanvas } from "@remotion/three";
import React, { useEffect, useState } from "react";
import * as THREE from "three";
import { AbsoluteFill, Audio, continueRender, delayRender, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { Scene } from "./Scene";
import { CodeBlocks, Captions, CtaSub, Flashes, gradeFilter, Grain, OSOverlay, Warmth } from "./Overlays";

const useFonts = () => {
  const [ready, setReady] = useState(false);
  const [handle] = useState(() => delayRender("fonts"));
  useEffect(() => {
    Promise.all([
      document.fonts.load('700 80px "Fredoka"'),
      document.fonts.load('600 80px "Fredoka"'),
      document.fonts.load('40px "VT323"'),
      document.fonts.load('500 20px "JetBrains Mono"'),
    ]).then(() => {
      setReady(true);
      continueRender(handle);
    });
  }, [handle]);
  return ready;
};

export const RetroDesktop: React.FC<{ withAudio?: boolean }> = ({ withAudio = true }) => {
  const { width, height } = useVideoConfig();
  const frame = useCurrentFrame();
  const t = frame / useVideoConfig().fps;
  const ready = useFonts();
  if (!ready) return null;
  return (
    <AbsoluteFill style={{ background: "#120804" }}>
      <AbsoluteFill style={{ filter: gradeFilter(t) }}>
        <ThreeCanvas width={width} height={height} shadows
          gl={{ antialias: false, toneMapping: THREE.NoToneMapping, preserveDrawingBuffer: true }}
          camera={{ fov: 40, near: 0.02, far: 30, position: [2.5, 2, 3.5] }}>
          <Scene />
        </ThreeCanvas>
      </AbsoluteFill>
      <Warmth />
      <OSOverlay />
      <CodeBlocks />
      <Flashes />
      <Grain />
      <Captions />
      <CtaSub />
      {withAudio && <Audio src={staticFile("audio.wav")} />}
    </AbsoluteFill>
  );
};
