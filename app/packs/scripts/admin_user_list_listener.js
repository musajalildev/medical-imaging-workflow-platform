document.addEventListener("turbo:load", () => {
  const forms = document.querySelectorAll(".role-form");

  forms.forEach((form) => {
    const roleDropdown = form.querySelector(".role-dropdown");
    const applyButton = form.querySelector(".apply-role-button");

    if (!roleDropdown || !applyButton) return;

    const initialRole = roleDropdown.value;

    const toggleApplyButton = () => {
      if (roleDropdown.value !== initialRole) {
        applyButton.style.visibility = "visible";
      } else {
        applyButton.style.visibility = "hidden";
      }
    };

    roleDropdown.addEventListener("change", toggleApplyButton);

    toggleApplyButton(); // run on page load
  });
});