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

  /*
   * TOBMATE_GSOS_PRESENCE_CLIENT_V1
   *
   * World Entry는 classroom3d.html이 담당한다.
   * 이 모듈은 발급된 Entry Session으로 Presence Hub에 연결한다.
   */
  var presenceSocket = null;
  var presenceSession = null;
  var presenceJoined = false;
  var presenceConnecting = false;
  var presenceMoveTimer = null;
  var lastPresencePosition = null;

  function getPresenceAdapter() {
    var classroom = window.TobmateClassroom3D;

    return (
      classroom &&
      classroom.presenceAdapter
    ) || null;
  }

  function normalizePresenceList(payload) {
    if (Array.isArray(payload)) {
      return payload;
    }

    if (
      payload &&
      Array.isArray(payload.users)
    ) {
      return payload.users;
    }

    if (
      payload &&
      Array.isArray(payload.presences)
    ) {
      return payload.presences;
    }

    return [];
  }

  function normalizePresence(payload) {
    if (!payload || typeof payload !== 'object') {
      return null;
    }

    return (
      payload.presence ||
      payload.user ||
      payload
    );
  }

  function positionHasChanged(position) {
    if (!lastPresencePosition) {
      return true;
    }

    return (
      Math.abs(
        position.x - lastPresencePosition.x
      ) > 0.03 ||
      Math.abs(
        position.y - lastPresencePosition.y
      ) > 0.03 ||
      Math.abs(
        position.z - lastPresencePosition.z
      ) > 0.03
    );
  }

  function stopPresenceMovement() {
    if (presenceMoveTimer) {
      clearInterval(presenceMoveTimer);
      presenceMoveTimer = null;
    }
  }

  function startPresenceMovement() {
    stopPresenceMovement();

    presenceMoveTimer = setInterval(function () {
      if (
        !presenceSocket ||
        !presenceSocket.connected ||
        !presenceJoined
      ) {
        return;
      }

      var adapter = getPresenceAdapter();

      if (
        !adapter ||
        typeof adapter.getLocalPose !== 'function'
      ) {
        return;
      }

      var pose = adapter.getLocalPose();

      if (!pose) {
        return;
      }

      var position = {
        x: Number(pose.x) || 0,
        y: Number(pose.y) || 0,
        z: Number(pose.z) || 0
      };

      if (!positionHasChanged(position)) {
        return;
      }

      lastPresencePosition = position;

      /*
       * Presence Hub에서 검증된 현재 프로토콜:
       * { x, y, z }
       */
      presenceSocket.emit(
        'presence:move',
        position,
        function (result) {
          if (result && result.ok === false) {
            console.warn(
              '[Avatar GSOS] presence:move 거절:',
              result
            );
          }
        }
      );
    }, 150);
  }

  function bindPresenceSocket(socket) {
    socket.on('presence:list', function (payload) {
      var adapter = getPresenceAdapter();

      if (!adapter) return;

      adapter.applyList(
        normalizePresenceList(payload).filter(
          function (presence) {
            return (
              presence &&
              presence.socketId !== socket.id
            );
          }
        )
      );
    });

    socket.on('presence:joined', function (payload) {
      var presence = normalizePresence(payload);
      var adapter = getPresenceAdapter();

      if (
        adapter &&
        presence &&
        presence.socketId !== socket.id
      ) {
        adapter.joined(presence);
      }
    });

    socket.on('presence:moved', function (payload) {
      var presence = normalizePresence(payload);
      var adapter = getPresenceAdapter();

      if (
        adapter &&
        presence &&
        presence.socketId !== socket.id
      ) {
        adapter.moved(presence);
      }
    });

    socket.on('presence:left', function (payload) {
      var presence = normalizePresence(payload);
      var adapter = getPresenceAdapter();

      if (adapter && presence) {
        adapter.left(presence);
      }
    });

    socket.on('disconnect', function (reason) {
      presenceJoined = false;
      stopPresenceMovement();

      console.warn(
        '[Avatar GSOS] Presence 연결 종료:',
        reason
      );
    });

    socket.on('connect_error', function (error) {
      presenceConnecting = false;

      console.error(
        '[Avatar GSOS] Presence 연결 실패:',
        error && error.message
          ? error.message
          : error
      );
    });
  }

  function connectPresenceFromSession(session) {
    if (
      !session ||
      !session.presence ||
      !session.presence.joinPayload
    ) {
      console.warn(
        '[Avatar GSOS] Presence joinPayload가 없습니다.',
        session
      );
      return null;
    }

    if (typeof window.io !== 'function') {
      console.warn(
        '[Avatar GSOS] Socket.IO가 아직 준비되지 않았습니다.'
      );
      return null;
    }

    if (!getPresenceAdapter()) {
      return null;
    }

    if (
      presenceSocket &&
      presenceSocket.connected &&
      presenceJoined
    ) {
      return presenceSocket;
    }

    if (presenceConnecting) {
      return presenceSocket;
    }

    presenceConnecting = true;
    presenceSession = session;

    /*
     * 기존 Classroom Socket은 그대로 유지한다.
     * GSOS Presence는 별도 path로 병렬 연결한다.
     *
     * Entry Ticket은 일회성일 수 있으므로 자동 재접속은
     * 이번 검증 단계에서는 끈다.
     */
    presenceSocket = window.io({
      path: '/gsos/presence/socket.io',
      transports: ['websocket', 'polling'],
      reconnection: false,
      timeout: 10000
    });

    bindPresenceSocket(presenceSocket);

    presenceSocket.on('connect', function () {
      console.log(
        '[Avatar GSOS] Presence Socket 연결:',
        presenceSocket.id
      );

      presenceSocket.emit(
        'presence:join',
        session.presence.joinPayload,
        function (result) {
          presenceConnecting = false;

          if (!result || result.ok !== true) {
            console.error(
              '[Avatar GSOS] Presence Join 실패:',
              result
            );

            return;
          }

          presenceJoined = true;
          lastPresencePosition = null;

          var adapter = getPresenceAdapter();

          if (adapter) {
            adapter.applyList(
              normalizePresenceList(result).filter(
                function (presence) {
                  return (
                    presence &&
                    presence.socketId !==
                      presenceSocket.id
                  );
                }
              )
            );
          }

          startPresenceMovement();

          console.log(
            '[Avatar GSOS] Presence Join 성공:',
            result.presence || result
          );

          window.dispatchEvent(
            new CustomEvent(
              'tobmate:gsos-presence-ready',
              {
                detail: {
                  socketId: presenceSocket.id,
                  session: presenceSession,
                  result: result
                }
              }
            )
          );
        }
      );
    });

    return presenceSocket;
  }

  function getGlobalPresenceSession() {
    if (
      !window.GSOS_ENTRY_TICKET ||
      !window.GSOS_PRESENCE
    ) {
      return null;
    }

    return {
      userId: window.GSOS_USER_ID || null,
      avatarId: window.GSOS_AVATAR_ID || null,
      spaceId: window.GSOS_SPACE_ID || null,
      ticket: window.GSOS_ENTRY_TICKET,
      presence: window.GSOS_PRESENCE
    };
  }

  function tryConnectPresence() {
    if (!presenceSession) {
      presenceSession =
        getGlobalPresenceSession();
    }

    if (
      !presenceSession ||
      !getPresenceAdapter() ||
      typeof window.io !== 'function'
    ) {
      return;
    }

    connectPresenceFromSession(
      presenceSession
    );
  }

  window.addEventListener(
    'tobmate:gsos-entry',
    function (event) {
      var detail =
        event && event.detail
          ? event.detail
          : null;

      presenceSession =
        detail && detail.session
          ? detail.session
          : detail;

      tryConnectPresence();
    }
  );

  window.addEventListener(
    'tobmate:classroom3d-presence-adapter-ready',
    tryConnectPresence
  );

  window.addEventListener(
    'load',
    tryConnectPresence
  );

  window.TobmateAvatarGSOS.connectPresence =
    connectPresenceFromSession;

  window.TobmateAvatarGSOS.getPresenceSocket =
    function () {
      return presenceSocket;
    };

  window.TobmateAvatarGSOS.isPresenceJoined =
    function () {
      return presenceJoined;
    };

  window.TobmateAvatarGSOS.disconnectPresence =
    function () {
      stopPresenceMovement();
      presenceJoined = false;
      presenceConnecting = false;

      if (presenceSocket) {
        presenceSocket.disconnect();
        presenceSocket = null;
      }

      var adapter = getPresenceAdapter();

      if (
        adapter &&
        typeof adapter.clear === 'function'
      ) {
        adapter.clear();
      }
    };


})();
