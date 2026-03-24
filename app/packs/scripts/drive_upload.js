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

  const form = container.closest('form');
  if (!form) {
    return;
  }

  const fileInput1 = document.getElementById('upload-file-input-1');
  const fileInput2 = document.getElementById('upload-file-input-2');
  const saveButton = form.querySelector('button[type="submit"]');
  const progressBar = document.getElementById('upload-progress');
  const progressText = document.getElementById('upload-progress-text');
  const statusText = document.getElementById('upload-status');
  const uploadedFilesJsonInput = document.getElementById('uploaded-files-json');

  const setProgress = (percent) => {
    progressBar.value = percent;
    progressText.textContent = `${percent}%`;
    console.log(`upload progress: ${percent}%`);
  };

  const setStatus = (message) => {
    statusText.textContent = message;
  };

  const resetSelectionState = () => {
    if (uploadedFilesJsonInput) {
      uploadedFilesJsonInput.value = '[]';
    }

    setProgress(0);
    setStatus('Ready');
  };

  fileInput1.addEventListener('change', resetSelectionState);
  fileInput2.addEventListener('change', resetSelectionState);

  let submittingAfterUpload = false;

  form.addEventListener('submit', async (event) => {
    if (submittingAfterUpload) {
      return;
    }

    event.preventDefault();

    const files = [
      fileInput1.files && fileInput1.files[0],
      fileInput2.files && fileInput2.files[0]
    ].filter(Boolean);

    if (uploadedFilesJsonInput) {
      uploadedFilesJsonInput.value = '[]';
    }

    if (files.length === 0) {
      setStatus('No files selected, saving job...');
      submittingAfterUpload = true;
      form.submit();
      return;
    }

    if (saveButton) {
      saveButton.disabled = true;
    }
    setProgress(0);
    setStatus('Uploading files before save...');

    try {
      const uploadedFiles = [];

      for (let index = 0; index < files.length; index += 1) {
        const file = files[index];
        setStatus(`Uploading ${index + 1}/${files.length}: ${file.name}`);

        console.log('uploading file:', file.name);
        const response = await uploadFileWithXhr(file, (filePercent) => {
          const overallPercent = Math.round(((index + (filePercent / 100)) / files.length) * 100);
          setProgress(overallPercent);
        });

        console.log('file_id:', response.file_id);
        uploadedFiles.push({
          file_id: response.file_id,
          file_type: file.type || 'application/octet-stream'
        });
      }

      if (uploadedFilesJsonInput) {
        uploadedFilesJsonInput.value = JSON.stringify(uploadedFiles);
      }

      setProgress(100);
      setStatus('Upload complete, saving job...');
      submittingAfterUpload = true;
      form.submit();
    } catch (error) {
      console.error(error);
      setStatus(error.message || 'Upload failed');
      if (saveButton) {
        saveButton.disabled = false;
      }
    }
  });
}

document.addEventListener('DOMContentLoaded', initializeDriveUpload);