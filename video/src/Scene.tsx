import { useThree, useFrame } from "@react-three/fiber";
import React, { useLayoutEffect, useMemo } from "react";
import { useCurrentFrame, useVideoConfig } from "remotion";
import * as THREE from "three";
import { FontLoader } from "three/examples/jsm/loaders/FontLoader.js";
import { TextGeometry } from "three/examples/jsm/geometries/TextGeometry.js";
import fontJson from "three/examples/fonts/helvetiker_bold.typeface.json";
import {
  BloomEffect, DepthOfFieldEffect, EffectComposer, EffectPass, RenderPass,
  SMAAEffect, ToneMappingEffect, ToneMappingMode,
} from "postprocessing";
import { cameraAt, PHONE, SCREEN } from "./camera";
import { CHAT_BUBBLES, CTA_WORD, SKILLS } from "./config";
import { drawBubble, drawPhone, drawScreen, XP_TIMES } from "./screen";
import { clamp01, easeIn, easeInOut, easeOut, lerp, rand, range, spring } from "./util";

// ── global look state, all functions of time ──────────────────────────
export const warmthAt = (t: number) => (t < 11 ? 1 : t < 14 ? 0 : easeInOut(range(t, 14.0, 15.3)));
export const wireAt = (t: number) => {
  if (t < 24.0 || t >= 27.0) return false;
  if (t > 26.55) return Math.floor(t * 30 / 2) % 2 === 0; // flicker back to the render
  return true;
};

const font = new FontLoader().parse(fontJson as any);
const italic = new THREE.Matrix4().set(1, 0.24, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
const makeText = (s: string, size: number, depth: number, slant = false) => {
  const g = new TextGeometry(s, {
    font, size, depth, curveSegments: 6,
    bevelEnabled: true, bevelThickness: depth * 0.25, bevelSize: size * 0.03, bevelSegments: 3,
  });
  if (slant) g.applyMatrix4(italic);
  g.computeBoundingBox();
  const b = g.boundingBox!;
  g.translate(-(b.max.x + b.min.x) / 2, -(b.max.y + b.min.y) / 2, -(b.max.z + b.min.z) / 2);
  return g;
};

const camQuat = (pos: THREE.Vector3, look: THREE.Vector3) =>
  new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().lookAt(pos, look, new THREE.Vector3(0, 1, 0)));

const useCanvasTexture = (w: number, h: number) =>
  useMemo(() => {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    const tex = new THREE.CanvasTexture(c);
    tex.colorSpace = THREE.SRGBColorSpace;
    tex.anisotropy = 8;
    return { c, ctx: c.getContext("2d")!, tex };
  }, [w, h]);

// ── materials ─────────────────────────────────────────────────────────
const M = {
  beige: new THREE.MeshStandardMaterial({ color: "#E3D2AE", roughness: 0.55, flatShading: true }),
  beigeDark: new THREE.MeshStandardMaterial({ color: "#C9B48C", roughness: 0.6, flatShading: true }),
  key: new THREE.MeshStandardMaterial({ color: "#EDE2C8", roughness: 0.5, flatShading: true }),
  keyDark: new THREE.MeshStandardMaterial({ color: "#8E7C62", roughness: 0.5, flatShading: true }),
  slot: new THREE.MeshStandardMaterial({ color: "#1a120c", roughness: 0.8 }),
  desk: new THREE.MeshStandardMaterial({ color: "#4A2A16", roughness: 0.45, metalness: 0.05, flatShading: true }),
  deskEdge: new THREE.MeshStandardMaterial({ color: "#2E190C", roughness: 0.5, flatShading: true }),
  wall: new THREE.MeshStandardMaterial({ color: "#D8B488", roughness: 0.9, flatShading: true }),
  wallSide: new THREE.MeshStandardMaterial({ color: "#C99E6E", roughness: 0.9, flatShading: true }),
  floor: new THREE.MeshStandardMaterial({ color: "#3A2213", roughness: 0.7, flatShading: true }),
  trim: new THREE.MeshStandardMaterial({ color: "#F2E4C8", roughness: 0.6, flatShading: true }),
  slat: new THREE.MeshStandardMaterial({ color: "#F4E6CC", roughness: 0.5, flatShading: true }),
  shelf: new THREE.MeshStandardMaterial({ color: "#5A3319", roughness: 0.6, flatShading: true }),
  lamp: new THREE.MeshStandardMaterial({ color: "#B8341F", roughness: 0.35, metalness: 0.3, flatShading: true }),
  metal: new THREE.MeshStandardMaterial({ color: "#2A2420", roughness: 0.4, metalness: 0.6, flatShading: true }),
  mug: new THREE.MeshStandardMaterial({ color: "#C9452A", roughness: 0.4, flatShading: true }),
  coffee: new THREE.MeshStandardMaterial({ color: "#2A140A", roughness: 0.2 }),
  pot: new THREE.MeshStandardMaterial({ color: "#B5582E", roughness: 0.8, flatShading: true }),
  leaf: new THREE.MeshStandardMaterial({ color: "#6E7F33", roughness: 0.7, flatShading: true }),
  leaf2: new THREE.MeshStandardMaterial({ color: "#8A8F38", roughness: 0.7, flatShading: true }),
  phone: new THREE.MeshStandardMaterial({ color: "#3B3936", roughness: 0.45, flatShading: true }),
  phoneKey: new THREE.MeshStandardMaterial({ color: "#8C877E", roughness: 0.5, flatShading: true }),
  bulb: new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 2.6, 1.2) }),
  pill: new THREE.MeshPhysicalMaterial({ color: "#140B06", roughness: 0.12, metalness: 0.35, clearcoat: 1, clearcoatRoughness: 0.05 }),
  ctaText: new THREE.MeshStandardMaterial({ color: "#FFE2A8", emissive: "#FF9A2E", emissiveIntensity: 0.55, roughness: 0.3, metalness: 0.2 }),
  label: new THREE.MeshStandardMaterial({ color: "#FFF1D6", emissive: "#FFB000", emissiveIntensity: 0.35, roughness: 0.35 }),
};
const bookColors = ["#C9302C", "#E8590C", "#FFB000", "#F2E4C8", "#6B3A1E", "#9C2F1B", "#D98E32"];
const bookMats = bookColors.map((c) => new THREE.MeshStandardMaterial({ color: c, roughness: 0.7, flatShading: true }));
const wireMat = new THREE.MeshBasicMaterial({ color: "#3DFF7A", wireframe: true });

const Box = ({ s, p, m, r }: { s: [number, number, number]; p: [number, number, number]; m: THREE.Material; r?: [number, number, number] }) => (
  <mesh position={p} rotation={r} material={m} castShadow receiveShadow>
    <boxGeometry args={s} />
  </mesh>
);

// ── Room ──────────────────────────────────────────────────────────────
const WIN = { y0: 0.95, y1: 2.35, z0: -0.75, z1: 1.15, x: -2.0 };

const Room = ({ t }: { t: number }) => {
  const sky = useMemo(() => {
    const c = document.createElement("canvas");
    c.width = 64;
    c.height = 256;
    const g = c.getContext("2d")!;
    const gr = g.createLinearGradient(0, 0, 0, 256);
    gr.addColorStop(0, "#FFB35C");
    gr.addColorStop(0.55, "#FF7A1A");
    gr.addColorStop(1, "#B83A12");
    g.fillStyle = gr;
    g.fillRect(0, 0, 64, 256);
    const tx = new THREE.CanvasTexture(c);
    tx.colorSpace = THREE.SRGBColorSpace;
    return tx;
  }, []);
  const w = warmthAt(t);
  const slats = 15;
  const h = WIN.y1 - WIN.y0;
  return (
    <group>
      {/* floor + ceiling */}
      <Box s={[4.6, 0.05, 5.6]} p={[0.2, -0.025, 1.4]} m={M.floor} />
      <Box s={[4.6, 0.05, 5.6]} p={[0.2, 2.95, 1.4]} m={M.wall} />
      {/* back wall */}
      <Box s={[4.6, 3.0, 0.1]} p={[0.2, 1.5, -1.35]} m={M.wall} />
      <Box s={[4.6, 0.12, 0.04]} p={[0.2, 0.06, -1.29]} m={M.trim} />
      {/* right wall */}
      <Box s={[0.1, 3.0, 5.6]} p={[2.5, 1.5, 1.4]} m={M.wallSide} />
      {/* left wall with a window hole */}
      <Box s={[0.1, WIN.y0, 5.6]} p={[WIN.x, WIN.y0 / 2, 1.4]} m={M.wallSide} />
      <Box s={[0.1, 3 - WIN.y1, 5.6]} p={[WIN.x, (3 + WIN.y1) / 2, 1.4]} m={M.wallSide} />
      <Box s={[0.1, h, WIN.z0 + 1.4]} p={[WIN.x, (WIN.y0 + WIN.y1) / 2, (WIN.z0 - 1.4) / 2]} m={M.wallSide} />
      <Box s={[0.1, h, 4.2 - WIN.z1]} p={[WIN.x, (WIN.y0 + WIN.y1) / 2, (WIN.z1 + 4.2) / 2]} m={M.wallSide} />
      {/* window frame + sill */}
      <Box s={[0.16, 0.06, WIN.z1 - WIN.z0 + 0.12]} p={[WIN.x + 0.02, WIN.y0 - 0.03, (WIN.z0 + WIN.z1) / 2]} m={M.trim} />
      <Box s={[0.16, 0.06, WIN.z1 - WIN.z0 + 0.12]} p={[WIN.x + 0.02, WIN.y1 + 0.03, (WIN.z0 + WIN.z1) / 2]} m={M.trim} />
      <Box s={[0.16, h, 0.06]} p={[WIN.x + 0.02, (WIN.y0 + WIN.y1) / 2, WIN.z0 - 0.03]} m={M.trim} />
      <Box s={[0.16, h, 0.06]} p={[WIN.x + 0.02, (WIN.y0 + WIN.y1) / 2, WIN.z1 + 0.03]} m={M.trim} />
      <Box s={[0.12, h, 0.04]} p={[WIN.x + 0.02, (WIN.y0 + WIN.y1) / 2, (WIN.z0 + WIN.z1) / 2]} m={M.trim} />
      {/* blinds: tilted slats → striped shadows */}
      {Array.from({ length: slats }).map((_, i) => (
        <mesh key={i} position={[WIN.x + 0.1, WIN.y0 + 0.05 + (i * (h - 0.1)) / (slats - 1), (WIN.z0 + WIN.z1) / 2]}
          rotation={[0, 0, 0.55]} material={M.slat} castShadow>
          <boxGeometry args={[0.075, 0.006, WIN.z1 - WIN.z0 - 0.02]} />
        </mesh>
      ))}
      {/* the outside: glowing golden-hour sky */}
      <mesh position={[WIN.x - 0.9, 1.6, 0.2]} rotation={[0, Math.PI / 2, 0]}>
        <planeGeometry args={[6, 4]} />
        <meshBasicMaterial map={sky} color={new THREE.Color(lerp(0.55, 2.2, w), lerp(0.55, 1.9, w), lerp(0.58, 1.6, w))} />
      </mesh>
    </group>
  );
};

// ── Desk + props ──────────────────────────────────────────────────────
const DESK_Y = 0.76;
const Desk = () => (
  <group>
    <Box s={[2.3, 0.06, 1.05]} p={[0, DESK_Y - 0.03, 0]} m={M.desk} />
    <Box s={[2.3, 0.03, 0.03]} p={[0, DESK_Y - 0.07, 0.51]} m={M.deskEdge} />
    {[[-1.08, -0.45], [1.08, -0.45], [-1.08, 0.45], [1.08, 0.45]].map(([x, z], i) => (
      <Box key={i} s={[0.07, DESK_Y - 0.06, 0.07]} p={[x, (DESK_Y - 0.06) / 2, z]} m={M.deskEdge} />
    ))}
    <Box s={[0.5, 0.42, 0.95]} p={[0.8, 0.45, 0]} m={M.desk} />
  </group>
);

const Keyboard = () => {
  const keys: React.JSX.Element[] = [];
  for (let r = 0; r < 4; r++)
    for (let c = 0; c < 13; c++)
      keys.push(
        <mesh key={`${r}-${c}`} position={[-0.27 + c * 0.045, 0.034 + r * 0.004, 0.065 - r * 0.042]}
          material={(r + c) % 7 === 0 ? M.keyDark : M.key} castShadow receiveShadow>
          <boxGeometry args={[0.036, 0.022, 0.034]} />
        </mesh>
      );
  return (
    <group position={[-0.15, DESK_Y, 0.33]} rotation={[0.05, 0, 0]}>
      <Box s={[0.66, 0.035, 0.22]} p={[0, 0.017, 0]} m={M.beige} />
      {keys}
      <mesh position={[-0.02, 0.03, 0.098]} material={M.key} castShadow>
        <boxGeometry args={[0.25, 0.02, 0.03]} />
      </mesh>
    </group>
  );
};

const Computer = ({ t, screenTex, screenGain }: { t: number; screenTex: THREE.Texture; screenGain: number }) => {
  // tips over to the left at 11.45–12.0 s, small bounce
  let ang = 0;
  if (t >= 11.45 && t < 14) {
    const f = easeIn(range(t, 11.45, 12.0));
    ang = f * (Math.PI / 2);
    if (t > 12.0) ang -= Math.sin(range(t, 12.0, 12.35) * Math.PI) * 0.12;
  }
  return (
    <group position={[-0.15 - 0.31, DESK_Y, -0.12]} rotation={[0, 0, ang]}>
      <group position={[0.31, 0, 0]}>
        {/* case */}
        <Box s={[0.62, 0.14, 0.5]} p={[0, 0.07, 0]} m={M.beige} />
        <Box s={[0.6, 0.01, 0.48]} p={[0, 0.142, 0]} m={M.beigeDark} />
        {/* floppy slot + led */}
        <Box s={[0.2, 0.05, 0.01]} p={[0.17, 0.075, 0.251]} m={M.beigeDark} />
        <Box s={[0.15, 0.008, 0.012]} p={[0.17, 0.08, 0.256]} m={M.slot} />
        <mesh position={[-0.24, 0.07, 0.253]}>
          <boxGeometry args={[0.02, 0.01, 0.006]} />
          <meshBasicMaterial color={new THREE.Color(0.4 + 2.5 * screenGain, 2.2 * screenGain + 0.2, 0.2)} />
        </mesh>
        {[0, 1, 2].map((i) => (
          <Box key={i} s={[0.06, 0.006, 0.01]} p={[-0.2 + i * 0.075, 0.03, 0.252]} m={M.beigeDark} />
        ))}
        {/* CRT */}
        <Box s={[0.5, 0.42, 0.09]} p={[0, 0.36, 0.205]} m={M.beige} />
        <Box s={[0.42, 0.36, 0.3]} p={[0, 0.355, 0.02]} m={M.beige} />
        <Box s={[0.3, 0.26, 0.18]} p={[0, 0.35, -0.2]} m={M.beigeDark} />
        <Box s={[0.44, 0.33, 0.01]} p={[0, 0.37, 0.248]} m={M.slot} />
        <mesh position={[0, 0.37, 0.2545]}>
          <planeGeometry args={[0.4, 0.3]} />
          <meshBasicMaterial map={screenTex} color={new THREE.Color(screenGain, screenGain, screenGain)} toneMapped={false} />
        </mesh>
        <Box s={[0.08, 0.02, 0.01]} p={[0.16, 0.175, 0.252]} m={M.beigeDark} />
      </group>
    </group>
  );
};

const Lamp = ({ on }: { on: number }) => (
  <group position={[0.82, DESK_Y, -0.3]}>
    <mesh material={M.lamp} castShadow position={[0, 0.015, 0]}>
      <cylinderGeometry args={[0.09, 0.1, 0.03, 10]} />
    </mesh>
    <mesh material={M.metal} castShadow position={[0, 0.2, 0.05]} rotation={[0.35, 0, 0]}>
      <cylinderGeometry args={[0.012, 0.012, 0.4, 6]} />
    </mesh>
    <mesh material={M.metal} castShadow position={[-0.08, 0.42, 0.09]} rotation={[0, 0, 1.0]}>
      <cylinderGeometry args={[0.012, 0.012, 0.25, 6]} />
    </mesh>
    <group position={[-0.2, 0.48, 0.1]} rotation={[0, 0, 0.75]}>
      <mesh material={M.lamp} castShadow>
        <coneGeometry args={[0.09, 0.15, 10, 1, true]} />
      </mesh>
      <mesh position={[0, -0.04, 0]} material={on > 0.5 ? M.bulb : M.slot}>
        <sphereGeometry args={[0.035, 10, 8]} />
      </mesh>
    </group>
  </group>
);

const Mug = () => (
  <group position={[0.42, DESK_Y, 0.2]}>
    <mesh material={M.mug} castShadow receiveShadow position={[0, 0.055, 0]}>
      <cylinderGeometry args={[0.045, 0.04, 0.11, 12]} />
    </mesh>
    <mesh material={M.coffee} position={[0, 0.1, 0]} rotation={[-Math.PI / 2, 0, 0]}>
      <circleGeometry args={[0.04, 12]} />
    </mesh>
    <mesh material={M.mug} castShadow position={[0.05, 0.055, 0]}>
      <torusGeometry args={[0.028, 0.008, 6, 10]} />
    </mesh>
  </group>
);

const Plant = ({ t }: { t: number }) => (
  <group position={[-0.9, DESK_Y, 0.3]}>
    <mesh material={M.pot} castShadow receiveShadow position={[0, 0.06, 0]}>
      <cylinderGeometry args={[0.07, 0.05, 0.12, 8]} />
    </mesh>
    {Array.from({ length: 9 }).map((_, i) => {
      const a = (i / 9) * Math.PI * 2;
      const sway = Math.sin(t * 1.3 + i) * 0.04;
      return (
        <mesh key={i} material={i % 2 ? M.leaf : M.leaf2} castShadow
          position={[Math.cos(a) * 0.05, 0.2 + rand(i) * 0.08, Math.sin(a) * 0.05]}
          rotation={[Math.sin(a) * 0.6 + sway, a, Math.cos(a) * 0.6]} scale={[0.6, 1.6, 0.25]}>
          <icosahedronGeometry args={[0.06, 0]} />
        </mesh>
      );
    })}
  </group>
);

const Phone = ({ tex, glow }: { tex: THREE.Texture; glow: number }) => (
  <group position={PHONE} rotation={[0, 0.12, 0]}>
    <Box s={[0.075, 0.022, 0.17]} p={[0, -0.018, 0]} m={M.phone} />
    <mesh position={[0, 0.0, -0.035]} rotation={[-Math.PI / 2, 0, 0]}>
      <planeGeometry args={[0.052, 0.065]} />
      <meshBasicMaterial map={tex} color={new THREE.Color(glow, glow, glow)} toneMapped={false} />
    </mesh>
    {Array.from({ length: 12 }).map((_, i) => (
      <mesh key={i} material={M.phoneKey} position={[-0.02 + (i % 3) * 0.02, -0.004, 0.02 + Math.floor(i / 3) * 0.013]}>
        <boxGeometry args={[0.015, 0.006, 0.009]} />
      </mesh>
    ))}
    <mesh material={M.phone} position={[0.025, -0.01, -0.095]} rotation={[Math.PI / 2, 0, 0]}>
      <cylinderGeometry args={[0.006, 0.006, 0.03, 6]} />
    </mesh>
  </group>
);

const Bookshelf = () => {
  const books: React.JSX.Element[] = [];
  [0.42, 0.92, 1.42].forEach((sy, s) => {
    let x = -0.38;
    let k = 0;
    while (x < 0.36) {
      const bw = 0.035 + rand(s * 31 + k) * 0.035;
      const bh = 0.24 + rand(s * 17 + k * 3) * 0.16;
      const lean = k === 6 && s === 1 ? 0.25 : 0;
      books.push(
        <mesh key={`${s}-${k}`} material={bookMats[Math.floor(rand(s * 7 + k * 13) * bookMats.length)]} castShadow receiveShadow
          position={[x + bw / 2, sy + bh / 2, 0]} rotation={[0, 0, -lean]}>
          <boxGeometry args={[bw, bh, 0.22]} />
        </mesh>
      );
      x += bw + 0.004 + (lean ? 0.06 : 0);
      k++;
    }
  });
  return (
    <group position={[1.7, 0, -1.12]}>
      <Box s={[0.9, 0.04, 0.3]} p={[0, 1.9, 0]} m={M.shelf} />
      {[0.4, 0.9, 1.4].map((y) => <Box key={y} s={[0.86, 0.025, 0.28]} p={[0, y, 0]} m={M.shelf} />)}
      <Box s={[0.04, 1.92, 0.3]} p={[-0.43, 0.96, 0]} m={M.shelf} />
      <Box s={[0.04, 1.92, 0.3]} p={[0.43, 0.96, 0]} m={M.shelf} />
      {books}
    </group>
  );
};

// ── Light: sun through blinds, shafts, dust ───────────────────────────
const Lights = ({ t }: { t: number }) => {
  const w = warmthAt(t);
  const scene = useThree((s) => s.scene);
  const sun = useMemo(() => {
    const l = new THREE.DirectionalLight();
    l.castShadow = true;
    l.shadow.mapSize.set(2048, 2048);
    l.shadow.bias = -0.0004;
    l.shadow.normalBias = 0.01;
    const sc = l.shadow.camera;
    sc.left = -2.6; sc.right = 2.6; sc.top = 2.6; sc.bottom = -2.6; sc.near = 0.5; sc.far = 14;
    return l;
  }, []);
  useLayoutEffect(() => {
    scene.add(sun.target);
    return () => { scene.remove(sun.target); };
  }, [scene, sun]);
  // the beam sweeps in from the right as the warmth returns
  const sweep = t >= 14 ? 1 - w : 0;
  const target = new THREE.Vector3(0.15 + sweep * 1.6, 0.85, -0.75);
  const dir = new THREE.Vector3(-2.0, 0.95, 1.05).normalize();
  sun.position.copy(target).addScaledVector(dir, 7);
  sun.target.position.copy(target);
  sun.target.updateMatrixWorld();
  sun.color.set("#FFB25E");
  sun.intensity = 7.5 * w;

  const ambCol = new THREE.Color("#8d8d8d").lerp(new THREE.Color("#ff9a55"), w);
  return (
    <>
      <primitive object={sun} />
      <ambientLight color={ambCol} intensity={lerp(1.5, 0.32, w)} />
      <hemisphereLight color={new THREE.Color("#bcbcbc").lerp(new THREE.Color("#ffc890"), w)}
        groundColor={new THREE.Color("#555").lerp(new THREE.Color("#4a2410"), w)} intensity={lerp(1.0, 0.45, w)} />
      {/* desk lamp */}
      <pointLight position={[0.6, 1.18, -0.2]} color="#FFA040" intensity={0.9 * w} distance={2.2} decay={2} />
      {/* CRT glow */}
      <pointLight position={[SCREEN[0], SCREEN[1], SCREEN[2] + 0.25]} color="#FF9A3C" intensity={0.5 * w} distance={1.4} decay={2} />
    </>
  );
};

const shaftTex = (() => {
  const c = document.createElement("canvas");
  c.width = 256;
  c.height = 64;
  const g = c.getContext("2d")!;
  const gr = g.createLinearGradient(0, 0, 256, 0);
  gr.addColorStop(0, "rgba(255,190,110,0.9)");
  gr.addColorStop(1, "rgba(255,150,60,0)");
  g.fillStyle = gr;
  g.fillRect(0, 0, 256, 64);
  // soft stripes
  for (let y = 0; y < 64; y += 8) {
    g.clearRect(0, y, 256, 3);
  }
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
})();

const Shafts = ({ t }: { t: number }) => {
  const w = warmthAt(t);
  if (w <= 0.01) return null;
  const dir = new THREE.Vector3(2.0, -0.95, -1.05).normalize();
  const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(1, 0, 0), dir);
  return (
    <group>
      {[-0.45, 0.0, 0.45, 0.85].map((z, i) => (
        <mesh key={i} position={new THREE.Vector3(WIN.x + 0.1, 1.65 + (i % 2) * 0.25, z).addScaledVector(dir, 1.1)} quaternion={q}>
          <planeGeometry args={[2.3, 0.6 + (i % 3) * 0.15]} />
          <meshBasicMaterial map={shaftTex} transparent opacity={0.07 * w} blending={THREE.AdditiveBlending} depthWrite={false} side={THREE.DoubleSide} />
        </mesh>
      ))}
    </group>
  );
};

const Dust = ({ t }: { t: number }) => {
  const geo = useMemo(() => new THREE.BufferGeometry(), []);
  const n = 140;
  const pos = new Float32Array(n * 3);
  for (let i = 0; i < n; i++) {
    const s = (t * 0.03 + rand(i * 3)) % 1;
    pos[i * 3] = -1.8 + rand(i) * 2.6 + Math.sin(t * 0.4 + i) * 0.05;
    pos[i * 3 + 1] = 0.8 + ((rand(i * 7) + s * 0.3) % 1) * 1.5;
    pos[i * 3 + 2] = -1.0 + rand(i * 11) * 1.9 + Math.cos(t * 0.3 + i) * 0.05;
  }
  geo.setAttribute("position", new THREE.BufferAttribute(pos, 3));
  const w = warmthAt(t);
  return (
    <points geometry={geo}>
      <pointsMaterial color={new THREE.Color(3, 2.2, 1.2)} size={0.008} transparent opacity={0.8 * w} blending={THREE.AdditiveBlending} depthWrite={false} />
    </points>
  );
};

// ── Chat bubbles (3–7 s) ──────────────────────────────────────────────
const Bubbles = ({ t, camQ }: { t: number; camQ: THREE.Quaternion }) => {
  const texes = useMemo(
    () =>
      CHAT_BUBBLES.map((txt, i) => {
        const c = document.createElement("canvas");
        c.width = 640;
        c.height = 240;
        drawBubble(c.getContext("2d")!, 640, 240, txt, i);
        const tx = new THREE.CanvasTexture(c);
        tx.colorSpace = THREE.SRGBColorSpace;
        return tx;
      }),
    []
  );
  if (t < 3.0 || t > 7.0) return null;
  const S = new THREE.Vector3(...SCREEN);
  return (
    <group>
      {texes.map((tx, i) => {
        const born = 3.1 + i * 0.25;
        if (t < born) return null;
        const out = spring(t - born, 11, 0.3);
        const a0 = (i / CHAT_BUBBLES.length) * Math.PI * 2 + 0.4;
        const a = a0 + (t - 3) * 0.55;
        const orbit = new THREE.Vector3(Math.cos(a) * 0.2, 0.02 + Math.sin(a * 0.9 + i) * 0.06 + (i - 2) * 0.11, 0.2 + Math.sin(a) * 0.2);
        const suckStart = 6.2 + i * 0.07;
        const suck = easeIn(range(t, suckStart, suckStart + 0.5));
        const p = S.clone().add(orbit.multiplyScalar(clamp01(out) * 0.9 + 0.1 * out).multiplyScalar(1 - suck));
        const sc = Math.max(0, out) * (1 - suck);
        if (sc <= 0.001) return null;
        const q = camQ.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(0, 0, Math.sin(t * 2 + i) * 0.08 + suck * 3)));
        return (
          <mesh key={i} position={p} quaternion={q} scale={[sc, sc, sc]}>
            <planeGeometry args={[0.2, 0.075]} />
            <meshBasicMaterial map={tx} transparent depthWrite={false} toneMapped={false} />
          </mesh>
        );
      })}
    </group>
  );
};

// ── Floating 3D skill labels (21–24 s) ────────────────────────────────
const LABEL_POS: [number, number, number][] = [
  [-0.3, 1.97, -0.6],
  [0.32, 1.8, -0.45],
  [-0.36, 1.55, -0.2],
  [0.33, 1.4, 0.1],
];
const Labels = ({ t, camQ }: { t: number; camQ: THREE.Quaternion }) => {
  const geos = useMemo(() => SKILLS.map((s) => makeText(s, 0.085, 0.03)), []);
  if (t < 21.2 || t >= 24.0) return null;
  return (
    <group>
      {geos.map((g, i) => {
        const born = 21.4 + i * 0.25;
        if (t < born) return null;
        const k = spring(t - born, 12, 0.3);
        const [x, y, z] = LABEL_POS[i];
        const bob = Math.sin((t - born) * 2.2 + i) * 0.03;
        const q = camQ.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(0, Math.sin(t * 1.5 + i) * 0.25, (i % 2 ? -1 : 1) * 0.05)));
        return <mesh key={i} geometry={g} material={M.label} position={[x, y + bob, z]} quaternion={q} scale={[k, k, k]} castShadow />;
      })}
    </group>
  );
};

// ── CTA pill (27–30 s) ────────────────────────────────────────────────
const CTA_T = 27.5; // impact lands on the beat
const makePill = (w: number, h: number) => {
  const r = h / 2;
  const s = new THREE.Shape();
  s.moveTo(-w / 2 + r, -h / 2);
  s.lineTo(w / 2 - r, -h / 2);
  s.absarc(w / 2 - r, 0, r, -Math.PI / 2, Math.PI / 2, false);
  s.lineTo(-w / 2 + r, h / 2);
  s.absarc(-w / 2 + r, 0, r, Math.PI / 2, (3 * Math.PI) / 2, false);
  const g = new THREE.ExtrudeGeometry(s, { depth: 0.02, bevelEnabled: true, bevelThickness: 0.012, bevelSize: 0.01, bevelSegments: 5, curveSegments: 24 });
  g.translate(0, 0, -0.03);
  return g;
};
const Cta = ({ t, cam }: { t: number; cam: { pos: THREE.Vector3; q: THREE.Quaternion } }) => {
  const { textGeo, pillGeo } = useMemo(() => {
    const tg = makeText(CTA_WORD, 0.044, 0.016, true);
    const b = tg.boundingBox!;
    return { textGeo: tg, pillGeo: makePill(b.max.x - b.min.x + 0.075, 0.095) };
  }, []);
  if (t < CTA_T - 0.3) return null;
  const fly = easeIn(range(t, CTA_T - 0.3, CTA_T));
  const settle = spring(t - CTA_T, 18, 0.28);
  const dist = lerp(0.18, 0.86, fly) + (t > CTA_T ? (1 - settle) * -0.04 : 0);
  const fwd = new THREE.Vector3(0, 0, -1).applyQuaternion(cam.q);
  const up = new THREE.Vector3(0, 1, 0).applyQuaternion(cam.q);
  const pos = cam.pos.clone().addScaledVector(fwd, dist).addScaledVector(up, 0.02 + Math.sin((t - CTA_T) * 2) * 0.004);
  const tilt = (1 - fly) * 0.6 + Math.sin((t - CTA_T) * 1.6) * 0.04;
  const q = cam.q.clone().multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(tilt * 0.4, Math.sin((t - CTA_T) * 1.2) * 0.07, -0.06 + tilt * 0.3)));
  return (
    <group position={pos} quaternion={q}>
      <mesh geometry={pillGeo} material={M.pill} />
      <mesh geometry={textGeo} material={M.ctaText} position={[0, -0.002, 0.016]} />
      <pointLight position={[0.15, 0.1, 0.25]} intensity={0.35} color="#FFD49A" distance={0.8} />
    </group>
  );
};

// ── Post-processing (rendering only, no animation) ────────────────────
const Post = ({ t, focus }: { t: number; focus: number }) => {
  const { gl, scene, camera, size } = useThree();
  const fx = useMemo(() => {
    const composer = new EffectComposer(gl, { frameBufferType: THREE.HalfFloatType });
    composer.addPass(new RenderPass(scene, camera));
    const dof = new DepthOfFieldEffect(camera, { worldFocusDistance: 1, worldFocusRange: 0.4, bokehScale: 3.2, resolutionScale: 0.5 });
    const bloom = new BloomEffect({ intensity: 1.0, luminanceThreshold: 0.72, luminanceSmoothing: 0.25, mipmapBlur: true, radius: 0.7 });
    const tone = new ToneMappingEffect({ mode: ToneMappingMode.ACES_FILMIC });
    composer.addPass(new EffectPass(camera, dof));
    composer.addPass(new EffectPass(camera, bloom, tone));
    composer.addPass(new EffectPass(camera, new SMAAEffect()));
    return { composer, dof, bloom };
  }, [gl, scene, camera]);
  useLayoutEffect(() => fx.composer.setSize(size.width, size.height), [fx, size]);
  const wire = wireAt(t);
  fx.dof.cocMaterial.worldFocusDistance = focus;
  fx.dof.cocMaterial.worldFocusRange = Math.max(0.18, focus * 0.45);
  fx.dof.bokehScale = wire ? 0.0 : 3.2;
  fx.bloom.intensity = wire ? 1.6 : lerp(0.35, 1.05, warmthAt(t));
  scene.overrideMaterial = wire ? wireMat : null;
  scene.background = new THREE.Color(wire ? "#010a03" : "#1a0d06");
  useFrame(() => fx.composer.render(), 1);
  return null;
};

// ── Scene root ────────────────────────────────────────────────────────
export const Scene = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps;
  const camera = useThree((s) => s.camera) as THREE.PerspectiveCamera;

  const crt = useCanvasTexture(640, 480);
  const lcd = useCanvasTexture(240, 300);

  const cam = cameraAt(t);
  // CTA impact shake
  if (t > CTA_T && t < CTA_T + 0.45) {
    const k = 1 - range(t, CTA_T, CTA_T + 0.45);
    cam.pos.x += (rand(frame * 1.3) - 0.5) * 0.02 * k;
    cam.pos.y += (rand(frame * 2.1) - 0.5) * 0.02 * k;
  }
  // tipping thud shake
  if (t > 12.0 && t < 12.3) {
    const k = 1 - range(t, 12.0, 12.3);
    cam.pos.y += (rand(frame * 3.1) - 0.5) * 0.03 * k;
  }
  const q = camQuat(cam.pos, cam.look);

  useLayoutEffect(() => {
    camera.position.copy(cam.pos);
    camera.quaternion.copy(q);
    camera.fov = cam.fov;
    camera.near = 0.02;
    camera.far = 30;
    camera.updateProjectionMatrix();
    camera.updateMatrixWorld();

    if (t >= 12.0 && t < 14.0) {
      // CRT switched off after the fall
      const k = range(t, 12.0, 12.25);
      crt.ctx.fillStyle = "#050505";
      crt.ctx.fillRect(0, 0, 640, 480);
      crt.ctx.fillStyle = `rgba(255,255,255,${1 - k})`;
      crt.ctx.fillRect(0, 240 - 4 * (1 - k), 640, 8 * (1 - k));
    } else {
      drawScreen(crt.ctx, 640, 480, t, frame);
    }
    crt.tex.needsUpdate = true;
    drawPhone(lcd.ctx, 240, 300, t);
    lcd.tex.needsUpdate = true;
  });

  const focus = cam.pos.distanceTo(cam.look);
  const screenGain = t >= 11 && t < 14 ? 1.0 : 1.7;
  const phoneGlow = t >= 12.5 && t < 14.5 ? 1.25 : 0.7;

  return (
    <>
      <Lights t={t} />
      <Room t={t} />
      <Desk />
      <Computer t={t} screenTex={crt.tex} screenGain={screenGain} />
      <Keyboard />
      <Lamp on={warmthAt(t)} />
      <Mug />
      <Plant t={t} />
      <Phone tex={lcd.tex} glow={phoneGlow} />
      <Bookshelf />
      <Shafts t={t} />
      <Dust t={t} />
      <Bubbles t={t} camQ={q} />
      <Labels t={t} camQ={q} />
      <Cta t={t} cam={{ pos: cam.pos, q }} />
      <Post t={t} focus={focus} />
    </>
  );
};

export { XP_TIMES, easeOut };
