#!/usr/bin/env bash
cd "$(dirname "$0")/.." || exit 1
python -m robot --outputdir qa/robot/output qa/robot/gate.robot
