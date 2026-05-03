function getCsrfToken() {
  const token = document.querySelector('meta[name="csrf-token"]');
  return token ? token.content : '';
}

const MAX_FILE_SIZE_BYTES = 1073741824; // 1 GB
const EMPTY_UPLOADS_JSON = JSON.stringify([
  { slot: 1, file_id: null, file_url: null, file_type: null },
  { slot: 2, file_id: null, file_url: null, file_type: null }
]);
const formStates = new WeakMap();

function uploadFileWithXhr(file, slot, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();

    formData.append('file', file);
    formData.append('slot', String(slot));

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

function isDriveUploadForm(form) {
  return Boolean(
    form &&
    form.querySelector('#drive-upload') &&
    form.querySelector('#upload-file-input-1') &&
    form.querySelector('#upload-file-input-2') &&
    form.querySelector('#uploaded-files-json')
  );
}

function getDriveUploadElements(form) {
  return {
    fileInput1: form.querySelector('#upload-file-input-1'),
    fileInput2: form.querySelector('#upload-file-input-2'),
    submitButtons: form.querySelectorAll('button[type="submit"]'),
    progressBar: form.querySelector('#upload-progress'),
    progressText: form.querySelector('#upload-progress-text'),
    statusText: form.querySelector('#upload-status'),
    uploadedFilesJsonInput: form.querySelector('#uploaded-files-json')
  };
}

function getFormState(form) {
  if (!formStates.has(form)) {
    formStates.set(form, { submittingAfterUpload: false });
  }

  return formStates.get(form);
}

function setProgress(elements, percent) {
  if (elements.progressBar) {
    elements.progressBar.value = percent;
  }

  if (elements.progressText) {
    elements.progressText.textContent = `${percent}%`;
  }
}

function setStatus(elements, message) {
  if (elements.statusText) {
    elements.statusText.textContent = message;
  }
}

function resetSelectionState(form) {
  if (!isDriveUploadForm(form)) {
    return;
  }

  const elements = getDriveUploadElements(form);
  const state = getFormState(form);
  state.submittingAfterUpload = false;

  if (elements.uploadedFilesJsonInput) {
    elements.uploadedFilesJsonInput.value = EMPTY_UPLOADS_JSON;
  }

  elements.submitButtons.forEach((btn) => { btn.disabled = false; });

  setProgress(elements, 0);
  setStatus(elements, 'Ready');
}

function validateFileBySlot(slot, file) {
  if (!file) {
    return null;
  }

  if (file.size > MAX_FILE_SIZE_BYTES) {
    return `${slot === 1 ? 'PDF file' : 'DICOM file'} exceeds 1 GB size limit.`;
  }

  const name = (file.name || '').toLowerCase();
  if (slot === 1 && !name.endsWith('.pdf')) {
    return 'PDF file must have .pdf extension.';
  }

  if (slot === 2 && !name.endsWith('.dcm')) {
    return 'DICOM file must have .dcm extension.';
  }

  return null;
}

function initializeDriveUpload() {
  const container = document.getElementById('drive-upload');
  if (!container) {
    return;
  }

  const form = container.closest('form');
  if (!isDriveUploadForm(form)) {
    return;
  }

  const elements = getDriveUploadElements(form);
  if (elements.uploadedFilesJsonInput && !elements.uploadedFilesJsonInput.value) {
    elements.uploadedFilesJsonInput.value = EMPTY_UPLOADS_JSON;
  }

  if (!elements.statusText || !elements.statusText.textContent.trim()) {
    setStatus(elements, 'Ready');
  }
}

document.addEventListener('change', (event) => {
  const target = event.target;
  if (!(target instanceof HTMLInputElement)) {
    return;
  }

  if (target.id !== 'upload-file-input-1' && target.id !== 'upload-file-input-2') {
    return;
  }

  resetSelectionState(target.form);
});

document.addEventListener('submit', async (event) => {
  const form = event.target;
  if (!(form instanceof HTMLFormElement) || !isDriveUploadForm(form)) {
    return;
  }

  const state = getFormState(form);
  if (state.submittingAfterUpload) {
    return;
  }

  const submitter = event.submitter;
  const elements = getDriveUploadElements(form);
  const selectedSlots = [
    { slot: 1, file: elements.fileInput1?.files?.[0] },
    { slot: 2, file: elements.fileInput2?.files?.[0] }
  ];
  const files = selectedSlots.filter((entry) => entry.file);
  const validationError = selectedSlots
    .map((entry) => validateFileBySlot(entry.slot, entry.file))
    .find(Boolean);

  if (validationError) {
    event.preventDefault();
    setStatus(elements, validationError);
    return;
  }

  if (files.length === 0) {
    setStatus(elements, 'No files selected, saving job...');
    return;
  }

  event.preventDefault();

  if (elements.uploadedFilesJsonInput) {
    elements.uploadedFilesJsonInput.value = EMPTY_UPLOADS_JSON;
  }

  elements.submitButtons.forEach((btn) => { btn.disabled = true; });

  setProgress(elements, 0);
  setStatus(elements, 'Uploading files before save...');

  try {
    const uploadedFiles = JSON.parse(EMPTY_UPLOADS_JSON);

    for (let index = 0; index < files.length; index += 1) {
      const selected = files[index];
      const file = selected.file;
      setStatus(elements, `Uploading ${index + 1}/${files.length}: ${file.name}`);

      const response = await uploadFileWithXhr(file, selected.slot, (filePercent) => {
        const overallPercent = Math.round(((index + (filePercent / 100)) / files.length) * 100);
        setProgress(elements, overallPercent);
      });

      uploadedFiles[selected.slot - 1] = {
        slot: selected.slot,
        file_id: response.file_id,
        file_url: response.file_url || null,
        file_type: file.type || 'application/octet-stream'
      };
    }

    if (elements.uploadedFilesJsonInput) {
      elements.uploadedFilesJsonInput.value = JSON.stringify(uploadedFiles);
    }

    setProgress(elements, 100);
    setStatus(elements, 'Upload complete, saving job...');

    if (submitter && submitter.name) {
      const hiddenInput = document.createElement('input');
      hiddenInput.type = 'hidden';
      hiddenInput.name = submitter.name;
      hiddenInput.value = submitter.value || '';
      form.appendChild(hiddenInput);
    }

    state.submittingAfterUpload = true;
    form.submit();
  } catch (error) {
    setStatus(elements, error.message || 'Upload failed');
    elements.submitButtons.forEach((btn) => { btn.disabled = false; });
  }
}, true);

document.addEventListener('DOMContentLoaded', initializeDriveUpload);
document.addEventListener('turbo:load', initializeDriveUpload);