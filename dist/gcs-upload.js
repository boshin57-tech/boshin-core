const { Storage } = require('@google-cloud/storage');
const fs = require('fs');
const path = require('path');

const storage = new Storage({ keyFilename: '/home/boshin57/Tobmate_Live/gcp-key.json' });
const BUCKET = 'tobmate-lectures';

// 파일 업로드
async function uploadFile(localPath, remotePath) {
  try {
    await storage.bucket(BUCKET).upload(localPath, {
      destination: remotePath,
      metadata: { cacheControl: 'no-cache' }
    });
    console.log(`[GCS] 업로드 완료: ${remotePath}`);
    return `https://storage.googleapis.com/${BUCKET}/${remotePath}`;
  } catch(e) {
    console.error('[GCS] 업로드 실패:', e.message);
    return null;
  }
}

// Buffer 직접 업로드 (녹화 데이터)
async function uploadBuffer(buffer, remotePath, contentType='video/webm') {
  try {
    const file = storage.bucket(BUCKET).file(remotePath);
    await file.save(buffer, { contentType, metadata: { cacheControl: 'no-cache' } });
    console.log(`[GCS] 버퍼 업로드 완료: ${remotePath}`);
    return `https://storage.googleapis.com/${BUCKET}/${remotePath}`;
  } catch(e) {
    console.error('[GCS] 버퍼 업로드 실패:', e.message);
    return null;
  }
}

// 서명된 URL 생성 (다운로드용)
async function getSignedUrl(remotePath, expiresMinutes=60) {
  try {
    const [url] = await storage.bucket(BUCKET).file(remotePath).getSignedUrl({
      action: 'read',
      expires: Date.now() + expiresMinutes * 60 * 1000
    });
    return url;
  } catch(e) {
    console.error('[GCS] URL 생성 실패:', e.message);
    return null;
  }
}

// 파일 목록 조회
async function listFiles(prefix='') {
  try {
    const [files] = await storage.bucket(BUCKET).getFiles({ prefix });
    return files.map(f => ({
      name: f.name,
      size: f.metadata.size,
      updated: f.metadata.updated,
      url: `https://storage.googleapis.com/${BUCKET}/${f.name}`
    }));
  } catch(e) {
    console.error('[GCS] 목록 조회 실패:', e.message);
    return [];
  }
}

module.exports = { uploadFile, uploadBuffer, getSignedUrl, listFiles };
