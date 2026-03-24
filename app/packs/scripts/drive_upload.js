function getCsrfToken() {
  const token = document.querySelector('meta[name="csrf-token"]');
  return token ? token.content : '';
}

function uploadFileWithXhr(file, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();

    formData.append('file', file);

    xhr.open('POST', '/files/upload', true);
    xhr.setRequestHeader('X-CSRF-Token', getCsrfToken());

    xhr.upload.onprogress = (event) => {
      if (!event.lengthComputable) {
        return;
      }

      const percent = Math.round((event.loaded / event.total) * 100);
      onProgress(percent);
    };

    xhr.onload = () => {
      let responseData;

      try {
        responseData = JSON.parse(xhr.responseText);
      } catch (_error) {
        responseData = null;
      }

      if (xhr.status >= 200 && xhr.status < 300) {
        resolve(responseData);
        return;
      }

      reject(new Error((responseData && responseData.error) || `Upload failed: ${xhr.status}`));
    };

    xhr.onerror = () => reject(new Error('Network error during file upload'));
    xhr.send(formData);
  });
}

function initializeDriveUpload() {
  const container = document.getElementById('drive-upload');

  if (!container) {
    return;
  }

  const fileInput = document.getElementById('upload-file-input');
  const uploadButton = document.getElementById('upload-button');
  const progressBar = document.getElementById('upload-progress');
  const progressText = document.getElementById('upload-progress-text');
  const statusText = document.getElementById('upload-status');
  const uploadedFileIdInput = document.getElementById('uploaded-file-id');
  const uploadedFileTypeInput = document.getElementById('uploaded-file-type');

  const setProgress = (percent) => {
    progressBar.value = percent;
    progressText.textContent = `${percent}%`;
    console.log(`upload progress: ${percent}%`);
  };

  const setStatus = (message) => {
    statusText.textContent = message;
  };

  fileInput.addEventListener('change', () => {
    if (uploadedFileIdInput) {
      uploadedFileIdInput.value = '';
    }

    if (uploadedFileTypeInput) {
      uploadedFileTypeInput.value = 'google_drive_file_id';
    }

    setProgress(0);
    setStatus('Ready');
  });

  uploadButton.addEventListener('click', async () => {
    const file = fileInput.files && fileInput.files[0];

    if (!file) {
      setStatus('Please select a file first.');
      return;
    }

    uploadButton.disabled = true;
    setProgress(0);
    setStatus('Uploading...');

    try {
      console.log('uploading file:', file.name);
      const response = await uploadFileWithXhr(file, setProgress);
      console.log('file_id:', response.file_id);

      if (uploadedFileIdInput) {
        uploadedFileIdInput.value = response.file_id || '';
      }

      if (uploadedFileTypeInput) {
        uploadedFileTypeInput.value = file.type || 'application/octet-stream';
      }

      setProgress(100);
      setStatus('Upload complete');
    } catch (error) {
      console.error(error);
      setStatus(error.message || 'Upload failed');
    } finally {
      uploadButton.disabled = false;
    }
  });
}

document.addEventListener('DOMContentLoaded', initializeDriveUpload);