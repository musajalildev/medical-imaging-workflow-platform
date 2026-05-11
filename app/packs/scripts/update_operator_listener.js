document.addEventListener("turbo:load", () => {
  const CURRENT_OPERATOR_EMAIL = document.getElementById("display_operator_email");
  const OPERATOR_SELECT = document.getElementById("operator_select");
  const REASSIGN_BUTTON = document.getElementById("update_operator_button");

  if (!CURRENT_OPERATOR_EMAIL || !OPERATOR_SELECT || !REASSIGN_BUTTON) return;

  const toggleReassignButton = () => {
    const selectedEmail = OPERATOR_SELECT.options[OPERATOR_SELECT.selectedIndex].text;
    if (selectedEmail !== CURRENT_OPERATOR_EMAIL.textContent) {
      REASSIGN_BUTTON.style.visibility = "visible";
    } else {
      REASSIGN_BUTTON.style.visibility = "hidden";
    }
  };

  OPERATOR_SELECT.addEventListener("change", toggleReassignButton);

  // run on page load too
  toggleReassignButton();
});

// fix the stuck button issue where the declining the turbo confirmation dialog would leave the button in a disabled state, this is a workaround to re-enable the button when the user cancels the confirmation dialog
document.addEventListener("click", (event) => {
  const button = event.target.closest("#update_operator_button");
  if (!button) return;

  setTimeout(() => {
    button.disabled = false;
  }, 100);
});