/*
 * PokeBonk iOS 控制桥
 *
 * 网页版 PokéBonk 的输入实现（逆向自其主 bundle）：
 *   - 键盘：window/document 上的 keydown / keyup，读 e.code（KeyW/KeyA/KeyS/KeyD/Space/ShiftLeft/KeyR/KeyE…）
 *   - 视角：window 上的 mousemove，读 e.movementX / e.movementY
 *           · 已拿到 pointer lock 时：无条件累加 movementX/Y
 *           · 未拿到锁时：只有 dragLook 为真 且 e.target === 锁定目标元素 且 (buttons & 1) 才累加
 *   - iOS 上没有真正的 pointer lock，所以这里做一层 requestPointerLock 垫片让游戏进入“已锁定”状态
 *
 * 本文件注入到 WKWebView (atDocumentStart)，对外暴露 window.__pb。
 */
(function () {
  'use strict';
  if (window.__pb) { return; }

  var S = {
    held: Object.create(null),   // 当前按住的 code
    lookMode: 'mouse',           // 'mouse' | 'touch'
    sensitivity: 1.0,
    invertY: false,
    cx: 0, cy: 0,                // 虚拟鼠标位置
    tx: 0, ty: 0,                // 虚拟触点位置
    touchDown: false,
    touchId: 7,
    lastRevert: 0,
    revertCount: 0,
    ready: false
  };

  /* ---------- 工具 ---------- */

  var KEY_DESC = {
    KeyW: ['w', 87], KeyA: ['a', 65], KeyS: ['s', 83], KeyD: ['d', 68],
    KeyQ: ['q', 81], KeyE: ['e', 69], KeyR: ['r', 82], KeyT: ['t', 84],
    KeyM: ['m', 77], KeyP: ['p', 80], KeyB: ['b', 66], KeyF: ['f', 70],
    Space: [' ', 32], ShiftLeft: ['Shift', 16], ShiftRight: ['Shift', 16],
    ControlLeft: ['Control', 17], AltLeft: ['Alt', 18],
    Escape: ['Escape', 27], Enter: ['Enter', 13], Tab: ['Tab', 9],
    ArrowUp: ['ArrowUp', 38], ArrowDown: ['ArrowDown', 40],
    ArrowLeft: ['ArrowLeft', 37], ArrowRight: ['ArrowRight', 39]
  };

  function patch(obj, prop, value) {
    try { Object.defineProperty(obj, prop, { get: function () { return value; }, configurable: true }); }
    catch (e) { /* 忽略 */ }
  }

  function canvasEl() {
    var el = document.querySelector('#game canvas') ||
             document.querySelector('canvas') ||
             document.getElementById('game');
    return el || document.body || document.documentElement;
  }

  /* ---------- 键盘 ---------- */

  function fireKey(type, code) {
    var d = KEY_DESC[code] || [code, 0];
    var ev = new KeyboardEvent(type, {
      bubbles: true, cancelable: true, composed: true,
      key: d[0], code: code, location: 0, repeat: false,
      ctrlKey: false, shiftKey: false, altKey: false, metaKey: false
    });
    patch(ev, 'keyCode', d[1]);
    patch(ev, 'which', d[1]);
    patch(ev, 'charCode', 0);
    // 从 canvas 派发：事件会冒泡经过 body → document → window，
    // 无论游戏把监听器挂在哪一层都能收到；e.target 也不是 INPUT/TEXTAREA，不会被过滤掉。
    var target = canvasEl();
    try { target.dispatchEvent(ev); } catch (e) {}
  }

  function setKey(code, down) {
    if (down) {
      if (S.held[code]) { return; }
      S.held[code] = true;
      fireKey('keydown', code);
    } else {
      if (!S.held[code]) { return; }
      delete S.held[code];
      fireKey('keyup', code);
    }
  }

  function tapKey(code) {
    setKey(code, true);
    setTimeout(function () { setKey(code, false); }, 70);
  }

  /* ---------- Pointer Lock 垫片 ---------- */

  var plTarget = null;

  function fireLockChange(el) {
    var ev = new Event('pointerlockchange');
    try { document.dispatchEvent(ev); } catch (e) {}
    if (el && el !== document && el.dispatchEvent) {
      try { el.dispatchEvent(new Event('pointerlockchange')); } catch (e) {}
    }
    if (typeof document.onpointerlockchange === 'function') {
      try { document.onpointerlockchange(ev); } catch (e) {}
    }
  }

  try {
    Object.defineProperty(document, 'pointerLockElement', {
      configurable: true,
      get: function () { return plTarget; }
    });
  } catch (e) {}

  Element.prototype.requestPointerLock = function (opts) { // eslint-disable-line
    plTarget = this;
    S.revertCount = 0;
    fireLockChange(this);
    return Promise.resolve();
  };

  Document.prototype.exitPointerLock = function () {
    var prev = plTarget;
    if (!prev) { return; }
    plTarget = null;
    S.revertCount += 1;
    S.lastRevert = Date.now();
    fireLockChange(prev);
  };
  document.exitPointerLock = Document.prototype.exitPointerLock;

  // 尝试进入锁定态。若游戏此刻并没有“想要锁定”(Pi)，它会立刻 exitPointerLock，
  // 这种回退会被计数并做退避，稍后（比如玩家真正进入对局时）再试。
  function ensureLock(force) {
    if (plTarget) { return; }
    var now = Date.now();
    if (!force && S.revertCount > 0 && now - S.lastRevert < 3000) { return; }
    var el = canvasEl();
    if (el && typeof el.requestPointerLock === 'function') {
      try { el.requestPointerLock(); } catch (e) {}
    }
  }

  /* ---------- 视角 ---------- */

  function mouseLook(dx, dy) {
    var el = canvasEl();
    var w = window.innerWidth || 800, h = window.innerHeight || 600;
    S.cx = Math.min(w - 1, Math.max(1, S.cx + dx));
    S.cy = Math.min(h - 1, Math.max(1, S.cy + dy));

    var ev = new MouseEvent('mousemove', {
      bubbles: true, cancelable: true, composed: true, view: window,
      clientX: S.cx, clientY: S.cy, screenX: S.cx, screenY: S.cy,
      button: 0, buttons: 1,
      ctrlKey: false, shiftKey: false, altKey: false, metaKey: false
    });
    patch(ev, 'movementX', dx);
    patch(ev, 'movementY', dy);
    patch(ev, 'offsetX', S.cx);
    patch(ev, 'offsetY', S.cy);
    try { el.dispatchEvent(ev); } catch (e) {}
  }

  function pointerEvent(type, x, y, dx, dy, buttons) {
    var ev = new PointerEvent(type, {
      bubbles: true, cancelable: true, composed: true, view: window,
      pointerId: S.touchId, pointerType: 'touch', isPrimary: true,
      clientX: x, clientY: y, screenX: x, screenY: y,
      button: 0, buttons: buttons, width: 1, height: 1, pressure: buttons ? 0.5 : 0
    });
    if (dx !== undefined) { patch(ev, 'movementX', dx); patch(ev, 'movementY', dy); }
    return ev;
  }

  function touchLook(dx, dy) {
    var el = canvasEl();
    var w = window.innerWidth || 800, h = window.innerHeight || 600;
    S.tx = Math.min(w - 1, Math.max(1, S.tx + dx));
    S.ty = Math.min(h - 1, Math.max(1, S.ty + dy));
    try {
      if (!S.touchDown) {
        S.touchDown = true;
        el.dispatchEvent(pointerEvent('pointerdown', S.tx, S.ty, 0, 0, 1));
        return;
      }
      el.dispatchEvent(pointerEvent('pointermove', S.tx, S.ty, dx, dy, 1));
    } catch (e) {}
  }

  function lookEnd() {
    if (S.lookMode === 'touch' && S.touchDown) {
      S.touchDown = false;
      try { canvasEl().dispatchEvent(pointerEvent('pointerup', S.tx, S.ty, 0, 0, 0)); } catch (e) {}
    }
  }

  /* ---------- 对外 API ---------- */

  window.__pb = {
    ready: function () { S.ready = true; ensureLock(true); },
    forceLock: function () { ensureLock(true); },

    /** 左摇杆：x 右为正，y 上为正，取值 -1~1 */
    move: function (x, y) {
      var t = 0.36;
      setKey('KeyD', x > t);
      setKey('KeyA', x < -t);
      setKey('KeyW', y > t);
      setKey('KeyS', y < -t);
    },

    /** 视角：屏幕坐标位移（点） */
    look: function (dx, dy) {
      if (!dx && !dy) { return; }
      dx = dx * S.sensitivity;
      dy = dy * S.sensitivity * (S.invertY ? -1 : 1);
      if (S.lookMode === 'touch') { touchLook(dx, dy); return; }
      ensureLock(false);
      mouseLook(dx, dy);
    },

    lookEnd: lookEnd,
    setKey: setKey,
    tapKey: tapKey,

    setSensitivity: function (v) { S.sensitivity = Math.max(0.2, Math.min(3, v || 1)); },
    setInvertY: function (v) { S.invertY = !!v; },
    setLookMode: function (m) { lookEnd(); S.lookMode = (m === 'touch') ? 'touch' : 'mouse'; },
    getState: function () { return { locked: !!plTarget, reverts: S.revertCount, mode: S.lookMode }; },

    reset: function () {
      for (var k in S.held) { if (S.held.hasOwnProperty(k)) { setKey(k, false); } }
      lookEnd();
    }
  };

  // 页面空闲时也偶尔尝试拿锁；一旦游戏进入对局会自然锁定成功
  setInterval(function () { if (S.ready) { ensureLock(false); } }, 4000);
})();
