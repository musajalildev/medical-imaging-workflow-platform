document.addEventListener("turbo:load", () => {
  const SELECT = document.getElementById("job_status");
  const CUSTOM_STATUS_FIELD = document.getElementById("custom_status_field");

  if (!SELECT) return;

  const toggleField = () => {
    if (SELECT.value === "custom") {
      CUSTOM_STATUS_FIELD.style.display = "block";
    } else {
      CUSTOM_STATUS_FIELD.style.display = "none";
    }
  };

  SELECT.addEventListener("change", toggleField);

  // run on page load too
  toggleField();
});