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

  async function buildOcrVariants(sourceBlob) {
    const bitmap = await createImageBitmap(sourceBlob);
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

  function mimeFromDataUrl(dataUrl) {
    const match = /^data:([^;,]+)[;,]/i.exec(String(dataUrl || ''));
    return match ? String(match[1] || '').toLowerCase() : '';
  }

  function readFileAsDataUrl(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result || ''));
      reader.onerror = () => reject(new Error('Не удалось прочитать файл'));
      reader.readAsDataURL(file);
    });
  }

  function readBlobAsDataUrl(blob) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(String(reader.result || ''));
      reader.onerror = () => reject(new Error('Не удалось прочитать blob'));
      reader.readAsDataURL(blob);
    });
  }

  function shouldUseNativeCameraInput() {
    const ua = String(navigator.userAgent || '');
    const isIPadOS =
      navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1;
    const isIOS = /iPhone|iPad|iPod/i.test(ua) || isIPadOS;
    const isAndroid = /Android/i.test(ua);
    return isIOS || isAndroid;
  }

  function pickVinFromFileInput(useCamera) {
    return new Promise((resolve) => {
      const input = document.createElement('input');
      input.type = 'file';
      input.multiple = false;
      input.accept = useCamera ? 'image/*' : 'image/*,.heic,.heif';
      if (useCamera) {
        input.capture = 'environment';
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
  }

  async function openLiveCameraStream() {
    if (
      !navigator.mediaDevices ||
      typeof navigator.mediaDevices.getUserMedia !== 'function'
    ) {
      throw new Error('Camera API unavailable');
    }

    const attempts = [
      {
        audio: false,
        video: {
          facingMode: { ideal: 'environment' },
          width: { ideal: 1920 },
          height: { ideal: 1080 },
        },
      },
      {
        audio: false,
        video: { facingMode: 'environment' },
      },
      {
        audio: false,
        video: true,
      },
    ];

    let lastError = null;
    for (const constraints of attempts) {
      try {
        return await navigator.mediaDevices.getUserMedia(constraints);
      } catch (error) {
        lastError = error;
      }
    }

    throw lastError || new Error('Не удалось открыть камеру');
  }

  async function pickVinFromLiveCamera() {
    const stream = await openLiveCameraStream();

    return new Promise((resolve) => {
      const overlay = document.createElement('div');
      overlay.style.position = 'fixed';
      overlay.style.inset = '0';
      overlay.style.background = 'rgba(0, 0, 0, 0.72)';
      overlay.style.zIndex = '2147483647';
      overlay.style.display = 'flex';
      overlay.style.alignItems = 'center';
      overlay.style.justifyContent = 'center';
      overlay.style.padding = '20px';

      const panel = document.createElement('div');
      panel.style.background = '#0f172a';
      panel.style.borderRadius = '12px';
      panel.style.padding = '12px';
      panel.style.width = 'min(640px, 94vw)';
      panel.style.maxHeight = '90vh';
      panel.style.display = 'flex';
      panel.style.flexDirection = 'column';
      panel.style.gap = '10px';

      const title = document.createElement('div');
      title.textContent = 'Наведите камеру на VIN и нажмите «Снять»';
      title.style.color = '#e2e8f0';
      title.style.font = '600 14px system-ui, -apple-system, sans-serif';

      const videoWrap = document.createElement('div');
      videoWrap.style.background = '#000';
      videoWrap.style.borderRadius = '10px';
      videoWrap.style.overflow = 'hidden';
      videoWrap.style.aspectRatio = '4 / 3';

      const video = document.createElement('video');
      video.autoplay = true;
      video.muted = true;
      video.playsInline = true;
      video.setAttribute('playsinline', 'true');
      video.style.width = '100%';
      video.style.height = '100%';
      video.style.objectFit = 'cover';
      video.srcObject = stream;
      videoWrap.appendChild(video);

      const actions = document.createElement('div');
      actions.style.display = 'flex';
      actions.style.justifyContent = 'space-between';
      actions.style.gap = '8px';

      const cancelBtn = document.createElement('button');
      cancelBtn.type = 'button';
      cancelBtn.textContent = 'Отмена';
      cancelBtn.style.flex = '1';
      cancelBtn.style.padding = '10px 12px';
      cancelBtn.style.borderRadius = '10px';
      cancelBtn.style.border = '1px solid #475569';
      cancelBtn.style.background = 'transparent';
      cancelBtn.style.color = '#e2e8f0';

      const captureBtn = document.createElement('button');
      captureBtn.type = 'button';
      captureBtn.textContent = 'Снять';
      captureBtn.style.flex = '1';
      captureBtn.style.padding = '10px 12px';
      captureBtn.style.borderRadius = '10px';
      captureBtn.style.border = 'none';
      captureBtn.style.background = '#0b5fff';
      captureBtn.style.color = '#ffffff';
      captureBtn.style.fontWeight = '600';

      actions.appendChild(cancelBtn);
      actions.appendChild(captureBtn);
      panel.appendChild(title);
      panel.appendChild(videoWrap);
      panel.appendChild(actions);
      overlay.appendChild(panel);
      document.body.appendChild(overlay);

      let settled = false;
      const settle = (value) => {
        if (settled) return;
        settled = true;
        resolve(value);
      };

      const stopStream = () => {
        stream.getTracks().forEach((track) => {
          try {
            track.stop();
          } catch (_) {}
        });
      };

      const cleanup = () => {
        stopStream();
        if (overlay.parentNode) {
          overlay.parentNode.removeChild(overlay);
        }
      };

      cancelBtn.addEventListener('click', () => {
        cleanup();
        settle('');
      });

      overlay.addEventListener('click', (event) => {
        if (event.target === overlay) {
          cleanup();
          settle('');
        }
      });

      const readyTimeout = window.setTimeout(() => {
        cleanup();
        settle('');
      }, 8000);

      const markReady = async () => {
        if (settled) return;
        try {
          await video.play();
          window.clearTimeout(readyTimeout);
        } catch (_) {
          cleanup();
          settle('');
        }
      };

      video.addEventListener('loadedmetadata', () => {
        void markReady();
      });
      void markReady();

      captureBtn.addEventListener('click', async () => {
        if (captureBtn.disabled) return;
        captureBtn.disabled = true;
        try {
          const width = Math.max(1, video.videoWidth || 1280);
          const height = Math.max(1, video.videoHeight || 720);
          const canvas = createCanvas(width, height);
          const ctx = canvas.getContext('2d');
          ctx.drawImage(video, 0, 0, width, height);
          const blob = await canvasToBlob(canvas);
          const dataUrl = await readBlobAsDataUrl(blob);
          cleanup();
          settle(dataUrl);
        } catch (_) {
          cleanup();
          settle('');
        }
      });
    });
  }

  window.vinPickImage = async function vinPickImage(useCamera) {
    if (useCamera) {
      try {
        const captured = await pickVinFromLiveCamera();
        if (captured) return captured;
      } catch (_) {
        if (shouldUseNativeCameraInput()) {
          return pickVinFromFileInput(true);
        }
      }
      return '';
    }
    return pickVinFromFileInput(false);
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

    try {
      const { createWorker } = window.Tesseract;
      const worker = await createWorker('eng', 1, { logger: () => {} });
      const psmModes = ['8', '7', '13', '6'];
      const sourceBlob = await dataUrlToBlob(dataUrl);
      let variants = [];
      try {
        variants = await buildOcrVariants(sourceBlob);
      } catch (_) {
        variants = [sourceBlob];
      }

      if (!variants.length) {
        variants = [sourceBlob];
      }

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
        const mime = mimeFromDataUrl(dataUrl);
        const unsupportedFormatHint =
          mime === 'image/heic' || mime === 'image/heif'
            ? ' Формат HEIC/HEIF может распознаваться нестабильно в браузере: попробуйте JPEG/PNG.'
            : '';
        return {
          vin: '',
          rawText: rawLines.join('\n'),
          error:
            'Не удалось уверенно распознать VIN. Снимите VIN крупнее, без бликов и строго по центру рамки.' +
            unsupportedFormatHint,
        };
      }

      return {
        vin: bestCandidate,
        rawText: rawLines.join('\n'),
        error: '',
      };
    } catch (error) {
      return {
        vin: '',
        rawText: '',
        error: `Ошибка OCR в браузере: ${error}`,
      };
    }
  };
})();
