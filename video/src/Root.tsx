import { Composition } from "remotion";
import { DURATION_S, FPS } from "./config";
import { RetroDesktop } from "./Video";

export const RemotionRoot = () => (
  <>
    <Composition id="RetroDesktop" component={RetroDesktop} durationInFrames={DURATION_S * FPS} fps={FPS} width={1080} height={1920} defaultProps={{ withAudio: true }} />
    {/* 60 fps silent pass: blended down to 30 fps in ffmpeg for real motion blur (see scripts/render.sh) */}
    <Composition id="RetroDesktop60" component={RetroDesktop} durationInFrames={DURATION_S * 60} fps={60} width={1080} height={1920} defaultProps={{ withAudio: false }} />
  </>
);
