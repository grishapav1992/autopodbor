(function () {
  const VIN_LENGTH = 17;
  const VIN_REGEX = /^[A-HJ-NPR-Z0-9]{17}$/;
  const TESSERACT_CDNS = [
    'https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js',
    'https://unpkg.com/tesseract.js@5/dist/tesseract.min.js',
  ];
  let tesseractLoadPromise = null;

  function loadScript(src) {
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = src;
      script.async = true;
      script.onload = () => resolve(true);
      script.onerror = () => reject(new Error(`Не удалось загрузить ${src}`));
      document.head.appendChild(script);
    });
  }

  async function ensureTesseractLoaded() {
    if (window.Tesseract && window.Tesseract.createWorker) return true;
    if (!tesseractLoadPromise) {
      tesseractLoadPromise = (async () => {
        for (const src of TESSERACT_CDNS) {
          try {
            await loadScript(src);
            if (window.Tesseract && window.Tesseract.createWorker) {
              return true;
            }
          } catch (_) {}
        }
        return false;
      })();
    }
    return tesseractLoadPromise;
  }

  function normalizeOcrText(raw) {
    return String(raw || '')
      .toUpperCase()
      .replace(/[А]/g, 'A')
      .replace(/[В]/g, 'B')
      .replace(/[С]/g, 'C')
      .replace(/[Е]/g, 'E')
      .replace(/[Н]/g, 'H')
      .replace(/[К]/g, 'K')
      .replace(/[М]/g, 'M')
      .replace(/[Р]/g, 'P')
      .replace(/[Т]/g, 'T')
      .replace(/[У]/g, 'Y')
      .replace(/[Х]/g, 'X')
      .replace(/[З]/g, '3')
      .replace(/[Б]/g, '6')
      .replace(/[І]/g, '1')
      .replace(/[|IL]/g, '1')
      .replace(/[OQ]/g, '0');
  }

  function cleanVin(raw) {
    return String(raw || '')
      .toUpperCase()
      .replace(/[^A-HJ-NPR-Z0-9]/g, '')
      .slice(0, VIN_LENGTH);
  }

  function isValidVin(vin) {
    return vin.length === VIN_LENGTH && VIN_REGEX.test(vin);
  }

  const VIN_WEIGHTS = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];
  const VIN_TRANSLITERATION = {
    A: 1,
    B: 2,
    C: 3,
    D: 4,
    E: 5,
    F: 6,
    G: 7,
    H: 8,
    J: 1,
    K: 2,
    L: 3,
    M: 4,
    N: 5,
    P: 7,
    R: 9,
    S: 2,
    T: 3,
    U: 4,
    V: 5,
    W: 6,
    X: 7,
    Y: 8,
    Z: 9,
  };

  function vinCharValue(char) {
    if (/^\d$/.test(char)) return Number(char);
    return VIN_TRANSLITERATION[char];
  }

  function hasValidVinChecksum(vin) {
    if (!isValidVin(vin)) return false;
    let sum = 0;
    for (let i = 0; i < VIN_LENGTH; i += 1) {
      const value = vinCharValue(vin[i]);
      if (value === undefined) return false;
      sum += value * VIN_WEIGHTS[i];
    }
    const remainder = sum % 11;
    const expected = remainder === 10 ? 'X' : String(remainder);
    return vin[8] === expected;
  }

  function passesVinHeuristics(vin) {
    if (!isValidVin(vin)) return false;
    if (!/[A-Z]/.test(vin) || !/\d/.test(vin)) return false;
    const digits = (vin.match(/\d/g) || []).length;
    const letters = (vin.match(/[A-Z]/g) || []).length;
    if (digits < 5 || letters < 3) return false;
    if (/^(.)\1+$/.test(vin)) return false;
    return true;
  }

  function candidateScore(vin, hits) {
    let score = hits;
    if (hasValidVinChecksum(vin)) score += 2;
    if (/^[A-HJ-NPR-Z]{3}/.test(vin)) score += 1;
    return score;
  }

  function extractVin(text) {
    const variants = [String(text || '').toUpperCase(), normalizeOcrText(text)];
    for (const variant of variants) {
      const cleaned = variant.replace(/[^A-HJ-NPR-Z0-9]/g, '');
      for (let i = 0; i <= cleaned.length - VIN_LENGTH; i += 1) {
        const candidate = cleaned.slice(i, i + VIN_LENGTH);
        if (isValidVin(candidate)) return candidate;
      }
    }
    return '';
  }

  async function dataUrlToBlob(dataUrl) {
    const response = await fetch(dataUrl);
    return response.blob();
  }

  function createCanvas(width, height) {
    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;
    return canvas;
  }

  function applyGrayscale(imageData) {
    const d = imageData.data;
    for (let i = 0; i < d.length; i += 4) {
      const g = d[i] * 0.299 + d[i + 1] * 0.587 + d[i + 2] * 0.114;
      d[i] = d[i + 1] = d[i + 2] = g;
    }
  }

  function applyContrast(imageData, factor) {
    const d = imageData.data;
    for (let i = 0; i < d.length; i += 4) {
      d[i] = Math.min(255, Math.max(0, (d[i] - 128) * factor + 128));
      d[i + 1] = Math.min(255, Math.max(0, (d[i + 1] - 128) * factor + 128));
      d[i + 2] = Math.min(255, Math.max(0, (d[i + 2] - 128) * factor + 128));
    }
  }

  function applyThreshold(imageData, threshold) {
    const d = imageData.data;
    for (let i = 0; i < d.length; i += 4) {
      const v = d[i] > threshold ? 255 : 0;
      d[i] = d[i + 1] = d[i + 2] = v;
    }
  }

  function makeVariantCanvas(bitmap, transforms) {
    const c = createCanvas(bitmap.width, bitmap.height);
    const ctx = c.getContext('2d');
    ctx.drawImage(bitmap, 0, 0);
    const img = ctx.getImageData(0, 0, c.width, c.height);
    transforms.forEach((fn) => fn(img));
    ctx.putImageData(img, 0, 0);
    return c;
  }

  function canvasToBlob(canvas) {
    return new Promise((resolve, reject) => {
      canvas.toBlob(
        (blob) => (blob ? resolve(blob) : reject(new Error('toBlob failed'))),
        'image/jpeg',
        0.92,
      );
    });
  }

  async function buildOcrVariants(dataUrl) {
    const source = await dataUrlToBlob(dataUrl);
    const bitmap = await createImageBitmap(source);
    const canvases = [
      makeVariantCanvas(bitmap, []),
      makeVariantCanvas(bitmap, [applyGrayscale]),
      makeVariantCanvas(bitmap, [
        applyGrayscale,
        (img) => applyContrast(img, 2.2),
      ]),
      makeVariantCanvas(bitmap, [
        applyGrayscale,
        (img) => applyContrast(img, 1.8),
        (img) => applyThreshold(img, 140),
      ]),
    ];
    bitmap.close();
    return Promise.all(canvases.map(canvasToBlob));
  }

  function readFileAsDataUrl(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result || ''));
      reader.onerror = () => reject(new Error('Не удалось прочитать файл'));
      reader.readAsDataURL(file);
    });
  }

  window.vinPickImage = function vinPickImage(useCamera) {
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.accept = 'image/*,.heic,.heif';
      if (useCamera) {
        input.setAttribute('capture', 'environment');
      }
      input.style.position = 'fixed';
      input.style.left = '-10000px';
      input.style.top = '-10000px';
      document.body.appendChild(input);

      const cleanup = () => {
        input.value = '';
        if (input.parentNode) {
          input.parentNode.removeChild(input);
        }
      };

      input.addEventListener(
        'change',
        async () => {
          const file = input.files && input.files[0];
          if (!file) {
            cleanup();
            resolve('');
            return;
          }
          try {
            const dataUrl = await readFileAsDataUrl(file);
            cleanup();
            resolve(dataUrl);
          } catch (_) {
            cleanup();
            resolve('');
          }
        },
        { once: true },
      );

      input.click();
    });
  };

  window.vinOcrScan = async function vinOcrScan(dataUrl) {
    const tesseractReady = await ensureTesseractLoaded();
    if (!tesseractReady) {
      return {
        vin: '',
        rawText: '',
        error: 'Не удалось загрузить OCR-движок.',
      };
    }

    if (!window.Tesseract || !window.Tesseract.createWorker) {
      return {
        vin: '',
        rawText: '',
        error: 'Tesseract.js не загружен',
      };
    }

    const { createWorker } = window.Tesseract;
    const worker = await createWorker('eng', 1, { logger: () => {} });
    const psmModes = ['8', '7', '13', '6'];
    const variants = await buildOcrVariants(dataUrl);

    let bestCandidate = '';
    const candidateHits = new Map();
    let bestScore = 0;
    const rawLines = [];

    try {
      for (const psm of psmModes) {
        await worker.setParameters({
          tessedit_char_whitelist: 'ABCDEFGHJKLMNPRSTUVWXYZ0123456789',
          tessedit_pageseg_mode: psm,
        });

        for (const variant of variants) {
          const { data } = await worker.recognize(variant);
          const raw = String(data && data.text ? data.text : '').trim();
          if (raw) rawLines.push(`[PSM${psm}] ${raw}`);

          const candidate = extractVin(raw);
          if (!candidate) continue;
          if (!passesVinHeuristics(candidate)) continue;

          const nextHits = (candidateHits.get(candidate) || 0) + 1;
          candidateHits.set(candidate, nextHits);
          const score = candidateScore(candidate, nextHits);
          if (!bestCandidate || score > bestScore) {
            bestCandidate = candidate;
            bestScore = score;
          }
        }

        if (bestScore >= 3) break;
      }
    } finally {
      await worker.terminate();
    }

    if (!bestCandidate || bestScore < 1) {
      return {
        vin: '',
        rawText: rawLines.join('\n'),
        error:
          'Не удалось уверенно распознать VIN. Снимите VIN крупнее, без бликов и строго по центру рамки.',
      };
    }

    return {
      vin: bestCandidate,
      rawText: rawLines.join('\n'),
      error: '',
    };
  };
})();
