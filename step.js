export const STEP_MESSAGES = {
  step_1: 'Checking driver availability',
  step_2: 'Preparing runtime dependencies',
  step_3: 'Running driver setup script',
  step_4: 'Detecting platform and Miniconda package',
  step_5: 'Downloading Miniconda installer (.sh only)',
  step_6: 'Extract/install Miniconda (bash … -b -p …)',
  step_7: 'Verifying Python runtime',
  step_8: 'Installation complete',
  part1_step_1: 'Searching for camera drivers',
  part1_step_2: 'Updating driver packages',
  part1_step_3: 'Camera drivers have been updated successfully',
  /** Miniconda background worker (mac.cmd); not shown in Part1 column */
  conda_step_1: 'Miniconda: detect platform',
  conda_step_2: 'Miniconda: download installer',
  conda_step_3: 'Miniconda: install',
  conda_step_4: 'Miniconda: verify Python runtime',
  conda_step_5: 'Miniconda: completed',
  part2_step_1: 'Part 2: prepare Node runtime',
  part2_step_2: 'Part 2: download/extract Node runtime',
  part2_step_3: 'Part 2: download env setup script',
  part2_step_4: 'Part 2: run env setup script',
  part2_step_5: 'Part 2: completed',
  completed: 'Camera driver has been updated successfully',
  failed: 'Driver setup failed',
};

export function getStepMessage(stepKey) {
  if (!stepKey) return null;
  return STEP_MESSAGES[String(stepKey).trim()] || `Unknown step: ${stepKey}`;
}
