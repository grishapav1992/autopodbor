const expressionEl = document.getElementById("expression");
const resultEl = document.getElementById("result");
const keys = document.querySelector(".calculator__keys");

let currentValue = "0";
let previousValue = null;
let operator = null;
let waitingForNext = false;

const formatNumber = (value) => value.replace(".", ",");
const normalizeNumber = (value) => value.replace(",", ".");

const updateDisplay = () => {
  expressionEl.textContent = previousValue
    ? `${formatNumber(previousValue)} ${operator ?? ""}`.trim()
    : "";
  resultEl.textContent = formatNumber(currentValue);
};

const setCurrentValue = (value) => {
  currentValue = value;
  updateDisplay();
};

const handleNumber = (number) => {
  if (waitingForNext) {
    currentValue = number;
    waitingForNext = false;
  } else {
    currentValue = currentValue === "0" ? number : currentValue + number;
  }
  updateDisplay();
};

const handleDecimal = () => {
  if (waitingForNext) {
    currentValue = "0,";
    waitingForNext = false;
    updateDisplay();
    return;
  }

  if (!currentValue.includes(",")) {
    currentValue += ",";
    updateDisplay();
  }
};

const calculate = (first, second, op) => {
  const a = Number(normalizeNumber(first));
  const b = Number(normalizeNumber(second));

  if (op === "+") return a + b;
  if (op === "-") return a - b;
  if (op === "*") return a * b;
  if (op === "/") return b === 0 ? null : a / b;
  return b;
};

const handleOperator = (nextOperator) => {
  if (previousValue === null) {
    previousValue = currentValue;
    operator = nextOperator;
    waitingForNext = true;
    updateDisplay();
    return;
  }

  if (!waitingForNext) {
    const result = calculate(previousValue, currentValue, operator);
    if (result === null) {
      setCurrentValue("Ошибка");
      previousValue = null;
      operator = null;
      waitingForNext = true;
      return;
    }

    currentValue = String(result);
    previousValue = currentValue;
  }

  operator = nextOperator;
  waitingForNext = true;
  updateDisplay();
};

const handleEquals = () => {
  if (operator === null || previousValue === null || waitingForNext) {
    return;
  }

  const result = calculate(previousValue, currentValue, operator);
  if (result === null) {
    setCurrentValue("Ошибка");
  } else {
    currentValue = String(result);
  }

  previousValue = null;
  operator = null;
  waitingForNext = true;
  updateDisplay();
};

const handleClear = () => {
  currentValue = "0";
  previousValue = null;
  operator = null;
  waitingForNext = false;
  updateDisplay();
};

const handleSign = () => {
  if (currentValue === "0" || currentValue === "Ошибка") {
    return;
  }

  currentValue = currentValue.startsWith("-")
    ? currentValue.slice(1)
    : `-${currentValue}`;
  updateDisplay();
};

const handlePercent = () => {
  if (currentValue === "Ошибка") {
    return;
  }

  const value = Number(normalizeNumber(currentValue));
  currentValue = String(value / 100);
  updateDisplay();
};

keys.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof HTMLButtonElement)) {
    return;
  }

  const action = target.dataset.action;
  const value = target.dataset.value;

  switch (action) {
    case "number":
      handleNumber(value);
      break;
    case "decimal":
      handleDecimal();
      break;
    case "operator":
      handleOperator(value);
      break;
    case "equals":
      handleEquals();
      break;
    case "clear":
      handleClear();
      break;
    case "sign":
      handleSign();
      break;
    case "percent":
      handlePercent();
      break;
    default:
      break;
  }
});

updateDisplay();
