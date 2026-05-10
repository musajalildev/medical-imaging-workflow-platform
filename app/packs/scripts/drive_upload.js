function getCsrfToken() {
  const token = document.querySelector('meta[name="csrf-token"]');
  return token ? token.content : '';
}

const MAX_FILE_SIZE_BYTES = 1073741824; // 1 GB
const EMPTY_UPLOADS_JSON = JSON.stringify([
  { slot: 1, file_id: null, file_url: null, file_type: null },
  { slot: 2, file_id: null, file_url: null, file_type: null, files: [] }
]);
const formStates = new WeakMap();

function uploadFileWithXhr(file, slot, onProgress, jobId = null, relativePath = null) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    const formData = new FormData();

    formData.append('file', file);
    formData.append('slot', String(slot));
    if (jobId) {
      formData.append('job_id', jobId);
    }
    if (relativePath) {
      formData.append('relative_path', relativePath);
    }

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
    dicomFolderModeToggle: form.querySelector('#upload-dicom-folder-mode'),
    submitButtons: form.querySelectorAll('button[type="submit"]'),
    progressBar: form.querySelector('#upload-progress-bar'),
    progressText: form.querySelector('#upload-progress-text'),
    statusText: form.querySelector('#upload-status'),
    uploadedFilesJsonInput: form.querySelector('#uploaded-files-json')
  };
}

function applyDicomInputMode(elements) {
  if (!elements.fileInput2) {
    return;
  }

  const folderModeEnabled = Boolean(elements.dicomFolderModeToggle?.checked);
  const inputLabel = document.getElementById('upload-file-input-2-label');
  const modeLabel = document.getElementById('upload-dicom-folder-mode-label');
  
  if (folderModeEnabled) {
    elements.fileInput2.removeAttribute('multiple');
    elements.fileInput2.setAttribute('webkitdirectory', '');
    elements.fileInput2.setAttribute('directory', '');
    if (inputLabel) inputLabel.textContent = 'DICOM folder';
    if (modeLabel) modeLabel.textContent = 'Upload individual files instead';
  } else {
    elements.fileInput2.setAttribute('multiple', 'true');
    elements.fileInput2.removeAttribute('webkitdirectory');
    elements.fileInput2.removeAttribute('directory');
    if (inputLabel) inputLabel.textContent = 'DICOM files';
    if (modeLabel) modeLabel.textContent = 'Upload as folder';
  }
}

function getFormState(form) {
  if (!formStates.has(form)) {
    formStates.set(form, { submittingAfterUpload: false });
  }

  return formStates.get(form);
}

function setProgress(elements, percent) {
  if (elements.progressBar) {
    elements.progressBar.style.width = `${percent}%`;
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
  applyDicomInputMode(elements);
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

  if (target.id !== 'upload-file-input-1' && target.id !== 'upload-file-input-2' && target.id !== 'upload-dicom-folder-mode') {
    return;
  }

  if (target.id === 'upload-dicom-folder-mode') {
    const form = target.form;
    const elements = getDriveUploadElements(form);
    if (elements.fileInput2) {
      elements.fileInput2.value = '';
    }
    applyDicomInputMode(elements);
  }

  resetSelectionState(target.form);
});

document.addEventListener('submit', async (event) => {
  const form = event.target;
  if (!(form instanceof HTMLFormElement) || !isDriveUploadForm(form)) {
    return;
  }

  const state = getFormState(form);

  // get the submitter now as we will need it to identify if the dialogue needs to be for a job or draft
  const submitter = event.submitter;

  if (!state.submittingAfterUpload) {

    // different confirmation message if this is a draft vs final submission
    let confimationMessage = 'You are about to create this job, are you sure?\nYou will no longer be able to edit it.\nIt will be visible to operators immediately after submission.';
    console.log(submitter?.name === 'save_as_draft');
    if (submitter?.name === 'save_as_draft') {
      confimationMessage = 'You are about to upload this job as a draft, are you sure?\nYou will be able to come back and edit it at any time.\nThe job will not be visible to operators until you choose to upload it.';
    }

    // no dialogue for updates, only for initial save or job creation
    if (submitter?.name === 'create_job' || submitter?.name === 'save_as_draft') {
      const confirmed = window.confirm(
        confimationMessage
      );

      if (!confirmed) {
        event.preventDefault();
        return;
      }
    }
  }

  const elements = getDriveUploadElements(form);

  // Determine if we should skip validation based on the type of submission
  const isDraftSave = submitter?.name === 'save_as_draft';
  const isDraftForm = form.querySelector('#drive-upload')?.dataset.isDraft === 'true';

  const isDraftUpdate = submitter?.name === 'update_draft';
  const skipValidation = isDraftSave || isDraftUpdate || (isDraftForm && !submitter?.name);

  // Validate required text fields before starting any upload
  const titleInput = form.querySelector('#job_title');
  if (!skipValidation) {
    const descriptionInput = form.querySelector('#job_description');
    const missingFields = [];
    if (titleInput && !titleInput.value.trim()) missingFields.push('Title can\'t be blank');
    if (descriptionInput && !descriptionInput.value.trim()) missingFields.push('Description can\'t be blank');
    if (missingFields.length > 0) {
      event.preventDefault();
      const errorBox = form.querySelector('#client-side-errors');
      if (errorBox) {
        const ul = errorBox.querySelector('ul');
        ul.innerHTML = missingFields.map((msg) => `<li>${msg}</li>`).join('');
        errorBox.style.display = '';
        window.scrollTo({ top: 0, behavior: 'smooth' });
      }
      return;
    }
  }

  // Clear any previous client-side errors
  const errorBox = form.querySelector('#client-side-errors');
  if (errorBox) errorBox.style.display = 'none';

  const dicomFiles = Array.from(elements.fileInput2?.files || []);

  const selectedSlots = [
    { slot: 1, files: elements.fileInput1?.files?.[0] ? [elements.fileInput1.files[0]] : [] },
    { slot: 2, files: dicomFiles }
  ];
  const files = selectedSlots.flatMap((entry) => entry.files.map((file) => ({ slot: entry.slot, file })));

  const hasExistingPdf = form.querySelectorAll('.job-upload-field')[0]?.dataset.hasFile === 'true';
  const hasExistingDicom = form.querySelectorAll('.job-upload-field')[1]?.dataset.hasFile === 'true';

  const fileErrors = [];
  if (!skipValidation) {
    if (selectedSlots[0].files.length === 0 && !hasExistingPdf)
      fileErrors.push("PDF file can't be blank");
    if (selectedSlots[1].files.length === 0 && !hasExistingDicom)
      fileErrors.push("DICOM file can't be blank");
  }

  if (fileErrors.length > 0) {
    event.preventDefault();
    const errorBox = form.querySelector('#client-side-errors');
    if (errorBox) {
      const ul = errorBox.querySelector('ul');
      ul.innerHTML = fileErrors.map((msg) => `<li>${msg}</li>`).join('');
      errorBox.style.display = '';
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }
    return;
  }

  const validationError = selectedSlots
    .flatMap((entry) => entry.files.map((file) => validateFileBySlot(entry.slot, file)))
    .find(Boolean);

  if (validationError) {
    event.preventDefault();
    setStatus(elements, validationError);
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
    // Extract job ID from the form's data attribute if it exists
    const jobId = form.querySelector('#drive-upload')?.dataset.jobId || null;
    
    const uploadedFiles = JSON.parse(EMPTY_UPLOADS_JSON);

    for (let index = 0; index < files.length; index += 1) {
      const selected = files[index];
      const file = selected.file;
      setStatus(elements, `Uploading ${index + 1}/${files.length}: ${file.name}`);

      const response = await uploadFileWithXhr(file, selected.slot, (filePercent) => {
        const overallPercent = Math.min(Math.round(((index + (filePercent / 100)) / files.length) * 100), 99);
        setProgress(elements, overallPercent);
      }, jobId, file.webkitRelativePath || null);

      if (selected.slot === 1) {
        uploadedFiles[0] = {
          slot: 1,
          file_id: response.file_id,
          file_url: response.file_url || null,
          file_type: file.type || 'application/octet-stream'
        };
      } else {
        if (!Array.isArray(uploadedFiles[1].files)) {
          uploadedFiles[1].files = [];
        }

        uploadedFiles[1].files.push({
          file_id: response.file_id,
          file_url: response.file_url || null,
          file_type: file.type || 'application/octet-stream',
          file_name: response.file_name || file.name || 'dicom-file',
          relative_path: response.relative_path || file.webkitRelativePath || file.name || 'dicom-file'
        });

        // Keep first file also at top-level keys for compatibility.
        if (!uploadedFiles[1].file_id) {
          uploadedFiles[1].file_id = response.file_id;
          uploadedFiles[1].file_url = response.file_url || null;
          uploadedFiles[1].file_type = file.type || 'application/octet-stream';
        }
      }
    }

    if (elements.uploadedFilesJsonInput) {
      elements.uploadedFilesJsonInput.value = JSON.stringify(uploadedFiles);
    }

    setProgress(elements, 99);
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