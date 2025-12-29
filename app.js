const expressionEl = document.getElementById("expression");
const resultEl = document.getElementById("result");
const keys = document.querySelector(".calculator__keys");
const historyList = document.getElementById("history");
const refreshButton = document.getElementById("refresh-history");
const usernameInput = document.getElementById("username");

const API_URL = "http://127.0.0.1:8001";

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
  const expression = `${formatNumber(previousValue)} ${operator} ${formatNumber(
    currentValue
  )}`;

  if (result === null) {
    setCurrentValue("Ошибка");
  } else {
    currentValue = String(result);
  }

  previousValue = null;
  operator = null;
  waitingForNext = true;
  updateDisplay();

  if (result !== null) {
    saveCalculation(expression, formatNumber(String(result)));
  }
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
  const result = value / 100;
  currentValue = String(result);
  updateDisplay();

  saveCalculation(`${formatNumber(value.toString())}%`, formatNumber(String(result)));
};

const getUsername = () => {
  const value = usernameInput.value.trim();
  return value.length > 0 ? value : "Гость";
};

const renderHistory = (items) => {
  historyList.innerHTML = "";

  if (!items.length) {
    const empty = document.createElement("li");
    empty.textContent = "История пока пуста.";
    empty.className = "history__item";
    historyList.appendChild(empty);
    return;
  }

  items.forEach((item) => {
    const listItem = document.createElement("li");
    listItem.className = "history__item";

    const title = document.createElement("strong");
    title.textContent = `${item.expression} = ${item.result}`;

    const meta = document.createElement("span");
    const date = new Date(item.created_at);
    meta.textContent = `${item.user} • ${date.toLocaleString("ru-RU")}`;

    listItem.append(title, meta);
    historyList.appendChild(listItem);
  });
};

const fetchHistory = async () => {
  try {
    const response = await fetch(`${API_URL}/calculations`);
    if (!response.ok) {
      throw new Error("Failed to fetch history");
    }
    const data = await response.json();
    renderHistory(data);
  } catch (error) {
    renderHistory([
      {
        expression: "Не удалось загрузить историю",
        result: "",
        user: "",
        created_at: new Date().toISOString(),
      },
    ]);
  }
};

const saveCalculation = async (expression, result) => {
  try {
    const response = await fetch(`${API_URL}/calculations`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        expression,
        result,
        user: getUsername(),
      }),
    });

    if (!response.ok) {
      return;
    }

    await fetchHistory();
  } catch (error) {
    // Ignore network errors for offline usage.
  }
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

refreshButton.addEventListener("click", () => {
  fetchHistory();
});

updateDisplay();
fetchHistory();
