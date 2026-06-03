import importlib
import json
import os
import sys
import urllib.parse
import urllib.request

from flask import Flask, jsonify, request
from flask_cors import CORS


PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
GROQ_MODEL = "groq/llama-3.3-70b-versatile"


def _load_crewai():
    """Load the installed CrewAI package even though this repo has crewai.py."""
    original_path = list(sys.path)
    project_realpath = os.path.realpath(PROJECT_DIR)

    try:
        sys.path = [
            path
            for path in sys.path
            if os.path.realpath(path or os.getcwd()) != project_realpath
        ]

        loaded_crewai = sys.modules.get("crewai")
        loaded_path = getattr(loaded_crewai, "__file__", "") if loaded_crewai else ""
        if loaded_path and os.path.realpath(loaded_path) == os.path.join(project_realpath, "crewai.py"):
            sys.modules.pop("crewai", None)

        crewai_module = importlib.import_module("crewai")
    finally:
        sys.path = original_path

    return crewai_module.Agent, crewai_module.Task, crewai_module.Crew, crewai_module.Process, crewai_module.LLM


Agent, Task, Crew, Process, LLM = _load_crewai()

app = Flask(__name__)
CORS(app)


llm = LLM(
    model=GROQ_MODEL,
    api_key=os.environ.get("GROQ_API_KEY"),
)


def _require_api_key():
    if not os.environ.get("GROQ_API_KEY"):
        return jsonify({"error": "GROQ_API_KEY environment variable is not set"}), 500
    return None


def _crew_output(result):
    raw = getattr(result, "raw", None)
    if raw:
        return raw
    return str(result)


def _exercise_body_part_for(goal):
    normalized_goal = str(goal or "").lower()
    if "weight" in normalized_goal or "loss" in normalized_goal or "endurance" in normalized_goal:
        return "cardio"
    if "muscle" in normalized_goal or "strength" in normalized_goal:
        return "chest"
    if "core" in normalized_goal:
        return "waist"
    return "cardio"


def _exercise_line(exercise):
    name = exercise.get("name", "Exercise")
    target = exercise.get("target") or exercise.get("targetMuscles", ["general"])
    equipment = exercise.get("equipment") or exercise.get("equipments", ["body weight"])

    if isinstance(target, list):
        target = ", ".join(target[:2])
    if isinstance(equipment, list):
        equipment = ", ".join(equipment[:2])

    return f"{name} | target: {target} | equipment: {equipment}"


def _fallback_exercises(goal):
    body_part = _exercise_body_part_for(goal)
    if body_part == "chest":
        return [
            "push up | target: pectorals | equipment: body weight",
            "incline push up | target: pectorals | equipment: body weight",
            "wide hand push up | target: pectorals | equipment: body weight",
            "chest dip | target: pectorals | equipment: body weight",
            "decline push up | target: pectorals | equipment: body weight",
        ]
    if body_part == "waist":
        return [
            "plank | target: abs | equipment: body weight",
            "crunch | target: abs | equipment: body weight",
            "mountain climber | target: abs | equipment: body weight",
            "side plank | target: obliques | equipment: body weight",
            "leg raise | target: abs | equipment: body weight",
        ]
    return [
        "jumping jack | target: cardiovascular system | equipment: body weight",
        "high knees | target: cardiovascular system | equipment: body weight",
        "burpee | target: cardiovascular system | equipment: body weight",
        "mountain climber | target: cardiovascular system | equipment: body weight",
        "squat | target: glutes | equipment: body weight",
    ]


def _fetch_exercisedb_exercises(goal, limit=8):
    api_key = os.environ.get("EXERCISEDB_RAPIDAPI_KEY")
    if not api_key:
        return _fallback_exercises(goal), "fallback-no-exercisedb-key"

    body_part = _exercise_body_part_for(goal)
    encoded_body_part = urllib.parse.quote(body_part)
    url = (
        f"https://exercisedb.p.rapidapi.com/exercises/bodyPart/{encoded_body_part}"
        f"?limit={limit}&offset=0"
    )
    request_headers = {
        "x-rapidapi-key": api_key,
        "x-rapidapi-host": "exercisedb.p.rapidapi.com",
    }

    try:
        exercise_request = urllib.request.Request(url, headers=request_headers)
        with urllib.request.urlopen(exercise_request, timeout=8) as response:
            payload = json.loads(response.read().decode("utf-8"))

        if not isinstance(payload, list) or not payload:
            return _fallback_exercises(goal), "fallback-empty-exercisedb-response"

        return [_exercise_line(exercise) for exercise in payload[:limit]], "exercisedb"
    except Exception as error:
        print(f"ExerciseDB fetch failed: {error}")
        return _fallback_exercises(goal), "fallback-exercisedb-error"


@app.get("/api/health")
def health():
    return jsonify({"status": "ok"})


@app.post("/api/chat")
def chat():
    api_key_error = _require_api_key()
    if api_key_error:
        return api_key_error

    data = request.get_json(silent=True) or {}
    message = data.get("message")

    if not message or not isinstance(message, str):
        return jsonify({"error": "Request body must include a non-empty 'message' string"}), 400

    fitness_coach_agent = Agent(
        role="FitnessCoach AI",
        goal="Give practical, safe, and personalized fitness guidance.",
        backstory=(
            "You are a supportive fitness coach for an iOS app. "
            "You answer clearly, keep recommendations realistic, and remind users "
            "to seek professional medical guidance for health concerns."
        ),
        llm=llm,
        verbose=True,
    )

    task = Task(
        description=(
            "Answer this user question about fitness:\n\n"
            f"{message}\n\n"
            "Return only the answer for the user."
        ),
        expected_output="A helpful fitness coaching response.",
        agent=fitness_coach_agent,
    )

    crew = Crew(
        agents=[fitness_coach_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True,
    )

    result = crew.kickoff()
    return jsonify({"response": _crew_output(result)})


@app.post("/api/analyze")
def analyze():
    api_key_error = _require_api_key()
    if api_key_error:
        return api_key_error

    data = request.get_json(silent=True) or {}
    steps = data.get("steps")
    calories = data.get("calories")
    heart_rate = data.get("heartRate")

    if steps is None or calories is None or heart_rate is None:
        return jsonify({"error": "Request body must include steps, calories, and heartRate"}), 400

    healthkit_agent = Agent(
        role="HealthKitAgent",
        goal="Analyze HealthKit fitness metrics and produce actionable recommendations.",
        backstory=(
            "You are a HealthKit-focused fitness analysis agent. "
            "You interpret steps, active calories, and heart rate for an iOS fitness app "
            "using clear recommendations that are appropriate for a general wellness product."
        ),
        llm=llm,
        verbose=True,
    )

    task = Task(
        description=(
            "Analyze these HealthKit metrics and give concise recommendations:\n"
            f"- Steps: {steps}\n"
            f"- Active calories: {calories}\n"
            f"- Heart rate: {heart_rate} bpm\n\n"
            "Return only the recommendation text."
        ),
        expected_output="A concise health and fitness recommendation.",
        agent=healthkit_agent,
    )

    crew = Crew(
        agents=[healthkit_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True,
    )

    result = crew.kickoff()
    return jsonify({"recommendation": _crew_output(result), "status": "completed"})

@app.post("/api/workout-recommendation")
def workout_recommendation():
    api_key_error = _require_api_key()
    if api_key_error:
        return api_key_error

    data = request.get_json(silent=True) or {}
    fitness_level = data.get("fitnessLevel", "intermediate")
    goal = data.get("goal", "general fitness")
    available_time = data.get("availableTime", 30)
    active_calories = data.get("activeCalories", 0)
    daily_goal = data.get("dailyGoal", 700)
    progress = data.get("progress", 0)
    exercise_candidates, exercise_source = _fetch_exercisedb_exercises(goal)

    ui_agent = Agent(
        role="UIAgent",
        goal="Generate personalized workout recommendations for a fitness app UI.",
        backstory=(
            "You are a UIAgent specialized in creating workout plans "
            "that are practical, safe, and tailored to the user's fitness level. "
            "You format recommendations clearly for display in a mobile app."
        ),
        llm=llm,
        verbose=True,
    )

    task = Task(
        description=(
            f"Create a workout recommendation for:\n"
            f"- Fitness level: {fitness_level}\n"
            f"- Goal: {goal}\n"
            f"- Available time: {available_time} minutes\n\n"
            f"- Active calories today: {active_calories}\n"
            f"- Daily calorie goal: {daily_goal}\n"
            f"- Goal progress: {progress}\n\n"
            "Use these ExerciseDB exercise candidates as the source list. "
            "Choose the safest and most relevant items from this list:\n"
            f"{chr(10).join('- ' + exercise for exercise in exercise_candidates)}\n\n"
            "Return a JSON object with this exact format:\n"
            '{"title": "Workout Name", "duration": "X Min", '
            '"exercises": ["Exercise 1 - 3x12", "Exercise 2 - 3x10"], '
            '"tip": "One practical tip"}\n'
            "Return ONLY the JSON, no explanation."
        ),
        expected_output="A JSON workout recommendation.",
        agent=ui_agent,
    )

    crew = Crew(
        agents=[ui_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True,
    )

    result = crew.kickoff()
    return jsonify({
        "workout": _crew_output(result),
        "status": "completed",
        "exerciseSource": exercise_source,
    })


@app.post("/api/validate")
def validate():
    api_key_error = _require_api_key()
    if api_key_error:
        return api_key_error

    data = request.get_json(silent=True) or {}
    content = data.get("content", "")
    content_type = data.get("type", "workout")

    qa_agent = Agent(
        role="QAAgent",
        goal="Validate fitness content for safety and accuracy before displaying to users.",
        backstory=(
            "You are a QAAgent that reviews fitness recommendations. "
            "You ensure content is safe, practical, and contains no medical claims. "
            "You flag anything inappropriate for a general wellness app."
        ),
        llm=llm,
        verbose=True,
    )

    task = Task(
        description=(
            f"Validate this {content_type} content for safety and appropriateness:\n\n"
            f"{content}\n\n"
            "Return a JSON object: "
            '{"isValid": true/false, "issues": [], "safeContent": "approved or modified content"}\n'
            "Return ONLY the JSON."
        ),
        expected_output="A JSON validation result.",
        agent=qa_agent,
    )

    crew = Crew(
        agents=[qa_agent],
        tasks=[task],
        process=Process.sequential,
        verbose=True,
    )

    result = crew.kickoff()
    return jsonify({"validation": _crew_output(result), "status": "completed"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
