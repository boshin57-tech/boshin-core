/*
 * Tobmate DOT Avatar ↔ GSOS Bridge
 *
 * 역할:
 * 1. 기존 tobmate_avatar_<user> 데이터를 유지
 * 2. 최초 1회 영구 avatarId 생성
 * 3. GSOS World Entry Ticket 요청
 * 4. Ticket/sessionStorage 저장
 * 5. Presence Hub 연결용 세션 노출
 */
(function () {
  'use strict';

  var params = new URLSearchParams(window.location.search);

  function clean(value, fallback) {
    value = String(value || '').trim();
    return value || fallback;
  }

  var userId = clean(params.get('user'), 'guest');

  function avatarStorageKey(user) {
    return 'tobmate_avatar_' + clean(user, 'guest');
  }

  function sessionStorageKey(spaceId) {
    return 'tobmate_gsos_entry_' + clean(spaceId, 'unknown');
  }

  function makeUuid() {
    if (
      window.crypto &&
      typeof window.crypto.randomUUID === 'function'
    ) {
      return window.crypto.randomUUID();
    }

    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
      .replace(/[xy]/g, function (char) {
        var random = Math.random() * 16 | 0;
        var value = char === 'x'
          ? random
          : (random & 0x3 | 0x8);

        return value.toString(16);
      });
  }

  function createAvatarId(user) {
    return 'avatar-' +
      clean(user, 'guest')
        .replace(/[^a-zA-Z0-9_-]/g, '-')
        .slice(0, 40) +
      '-' +
      makeUuid();
  }

  function readAvatar(user) {
    var resolvedUser = clean(user, userId);
    var key = avatarStorageKey(resolvedUser);
    var avatar = {};

    try {
      var raw = localStorage.getItem(key);

      if (raw) {
        var parsed = JSON.parse(raw);

        if (
          parsed &&
          typeof parsed === 'object' &&
          !Array.isArray(parsed)
        ) {
          avatar = parsed;
        }
      }
    } catch (error) {
      console.warn(
        '[Avatar GSOS] 기존 아바타 읽기 실패:',
        error
      );
    }

    return avatar;
  }

  function writeAvatar(user, avatar) {
    var resolvedUser = clean(user, userId);
    var key = avatarStorageKey(resolvedUser);

    localStorage.setItem(
      key,
      JSON.stringify(avatar)
    );

    return avatar;
  }

  function ensureIdentity(user) {
    var resolvedUser = clean(user, userId);
    var avatar = readAvatar(resolvedUser);
    var changed = false;

    if (!avatar.avatarId) {
      avatar.avatarId = createAvatarId(resolvedUser);
      changed = true;
    }

    if (!avatar.userId) {
      avatar.userId = resolvedUser;
      changed = true;
    }

    if (!avatar.identityVersion) {
      avatar.identityVersion = 1;
      changed = true;
    }

    if (!avatar.createdAt) {
      avatar.createdAt = new Date().toISOString();
      changed = true;
    }

    if (changed) {
      avatar.updatedAt = new Date().toISOString();
      writeAvatar(resolvedUser, avatar);
    }

    return avatar;
  }

  function updateAvatar(patch, user) {
    var resolvedUser = clean(user, userId);
    var avatar = ensureIdentity(resolvedUser);

    Object.keys(patch || {}).forEach(function (key) {
      if (
        key === 'avatarId' &&
        avatar.avatarId &&
        patch.avatarId !== avatar.avatarId
      ) {
        return;
      }

      avatar[key] = patch[key];
    });

    avatar.userId = resolvedUser;
    avatar.updatedAt = new Date().toISOString();

    writeAvatar(resolvedUser, avatar);

    window.dispatchEvent(
      new CustomEvent('tobmate:avatar-updated', {
        detail: avatar
      })
    );

    return avatar;
  }

  function extractEntryTicket(data) {
    if (!data || typeof data !== 'object') {
      return null;
    }

    return (
      data.entryTicket ||
      data.ticket ||
      (data.entry && data.entry.ticket) ||
      (data.data && data.data.ticket) ||
      null
    );
  }

  function extractPresence(data) {
    if (!data || typeof data !== 'object') {
      return null;
    }

    return (
      data.presence ||
      (data.entry && data.entry.presence) ||
      (data.data && data.data.presence) ||
      null
    );
  }

  async function enterWorld(spaceId, options) {
    options = options || {};

    var resolvedSpaceId = clean(spaceId, 'classroom3d-s18');
    var avatar = ensureIdentity(userId);

    var response = await fetch(
      '/gsos/api/worlds/' +
        encodeURIComponent(resolvedSpaceId) +
        '/enter',
      {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          userId: userId,
          avatarId: avatar.avatarId,
          spaceId: resolvedSpaceId,
          metadata: {
            source: 'dot-metaverse',
            pathname: window.location.pathname,
            language: clean(params.get('lang'), 'ko'),
            avatarVersion: avatar.identityVersion || 1
          }
        })
      }
    );

    var data;

    try {
      data = await response.json();
    } catch (error) {
      data = {
        error: 'GSOS가 JSON 응답을 반환하지 않았습니다.'
      };
    }

    if (!response.ok) {
      var message =
        data.message ||
        data.error ||
        ('GSOS World Entry 실패: HTTP ' + response.status);

      throw new Error(message);
    }

    var session = {
      ok: true,
      userId: userId,
      avatarId: avatar.avatarId,
      spaceId: resolvedSpaceId,
      ticket: extractEntryTicket(data),
      presence: extractPresence(data),
      response: data,
      enteredAt: new Date().toISOString()
    };

    sessionStorage.setItem(
      sessionStorageKey(resolvedSpaceId),
      JSON.stringify(session)
    );

    sessionStorage.setItem(
      'tobmate_gsos_current_entry',
      JSON.stringify(session)
    );

    window.TobmateGSOSSession = session;

    window.dispatchEvent(
      new CustomEvent('tobmate:gsos-entry', {
        detail: session
      })
    );

    console.log(
      '[Avatar GSOS] World Entry 성공:',
      session
    );

    return session;
  }

  function getCurrentSession() {
    try {
      var raw = sessionStorage.getItem(
        'tobmate_gsos_current_entry'
      );

      return raw ? JSON.parse(raw) : null;
    } catch (error) {
      return null;
    }
  }

  function getIdentity() {
    return ensureIdentity(userId);
  }

  window.TobmateAvatarGSOS = {
    version: '1.0.0',
    userId: userId,
    getIdentity: getIdentity,
    readAvatar: readAvatar,
    updateAvatar: updateAvatar,
    enterWorld: enterWorld,
    getCurrentSession: getCurrentSession
  };

  var identity = ensureIdentity(userId);

  document.documentElement.setAttribute(
    'data-tobmate-user-id',
    identity.userId
  );

  document.documentElement.setAttribute(
    'data-tobmate-avatar-id',
    identity.avatarId
  );

  window.dispatchEvent(
    new CustomEvent('tobmate:avatar-ready', {
      detail: identity
    })
  );
})();
