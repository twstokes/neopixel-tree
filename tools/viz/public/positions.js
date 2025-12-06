export const PIXEL_COUNT = 106;

// 90 pixels spiral up the tree body, 16 form a ring at the star base
export const lightPositions = buildPositions();

function buildPositions() {
  const positions = [];
  const treePixels = 90;
  const height = 2.4 * 0.85;
  const baseRadius = 0.9; // keep pixels outside the cone surface
  const turns = 5.5;
  const verticalShift = -0.0; // drop lights so top ring sits at star base

  for (let i = 0; i < treePixels; i++) {
    const t = i / (treePixels - 1);
    const angle = t * turns * Math.PI * 2;
    const radius = baseRadius * (1 - 0.75 * t);
    const y = 0.05 + t * height + verticalShift;
    positions.push({
      x: Math.cos(angle) * radius,
      y,
      z: Math.sin(angle) * radius,
    });
  }

  const starPixels = 16;
  const starRadius = 0.22;
  const starHeight = height + 0.25 + verticalShift;
  for (let j = 0; j < starPixels; j++) {
    const angle = (j / starPixels) * Math.PI * 2;
    positions.push({
      x: Math.cos(angle) * starRadius,
      y: starHeight,
      z: Math.sin(angle) * starRadius,
    });
  }

  return positions;
}
