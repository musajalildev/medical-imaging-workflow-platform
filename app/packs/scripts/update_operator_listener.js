document.addEventListener("turbo:load", () => {
  const CURRENT_OPERATOR_EMAIL = document.getElementById("display_operator_email");
  const OPERATOR_SELECT = document.getElementById("operator_select");
  const REASSIGN_BUTTON = document.getElementById("update_operator_button");

  if (!CURRENT_OPERATOR_EMAIL || !OPERATOR_SELECT || !REASSIGN_BUTTON) return;

  const toggleReassignButton = () => {
    const SELECTED_EMAIL = OPERATOR_SELECT.options[OPERATOR_SELECT.selectedIndex].text;
    if (SELECTED_EMAIL !== CURRENT_OPERATOR_EMAIL.textContent) {
      REASSIGN_BUTTON.style.visibility = "visible";
    } else {
      REASSIGN_BUTTON.style.visibility = "hidden";
    }
  };

  OPERATOR_SELECT.addEventListener("change", toggleReassignButton);

  // run on page load too
  toggleReassignButton();
});

// add confirmation dialogue on the submitter
document.addEventListener("click", (event) => {
  const button = event.target.closest("#update_operator_button");
  if (!button) return;

  event.preventDefault();

  const form = button.closest("form");

  const OPERATOR_SELECT = document.getElementById("operator_select");
  const SELECTED_EMAIL = OPERATOR_SELECT.options[OPERATOR_SELECT.selectedIndex].text;
  const CURRENT_OPERATOR_EMAIL = document.getElementById("display_operator_email")?.textContent.trim();

  let confirmationMessage = "You are about to unassign " + CURRENT_OPERATOR_EMAIL + " from this job, meaning they will no longer be able to work on it.\n";
  switch (SELECTED_EMAIL) {
    case "No Operator":
      confirmationMessage += "\nAre you sure?";
    break;
    default:
      confirmationMessage += "You will then assign " + SELECTED_EMAIL + " as the new operator.\n\nAre you sure?";
    break;
  }

  const confirmed = window.confirm(confirmationMessage);
  if (confirmed) {
    form.requestSubmit(button);
  }
});
