document.addEventListener("turbo:load", () => {
  const SELECT = document.getElementById("job_status");
  const STATUS_DISPLAY = document.getElementById("status_display");
  const SAVE_CHANGES_BUTTON = document.getElementById("save_changes_button");

  if (!SELECT) return;

  const toggleField = () => {
    if (SELECT.value != STATUS_DISPLAY.textContent.toLowerCase()) {
      SAVE_CHANGES_BUTTON.style.display = "block";
    } else {
      SAVE_CHANGES_BUTTON.style.display = "none";
    }
  };

  SELECT.addEventListener("change", toggleField);

  // run on page load too
  toggleField();
});