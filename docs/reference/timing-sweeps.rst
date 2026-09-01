ECP5 Timing and Seed Sweeps
===========================

Hazard3-Doom uses repeated nextpnr-ecp5 place-and-route runs to characterize
ECP5 timing, select useful seeds, compare place-and-route settings, and catch
timing regressions after RTL or generated-core changes. The same sweep scripts
are used locally and by the GitHub Actions ``ECP5 seed sweep`` workflow.

A sweep is more than a search for a lucky seed. It is also a reproducible
experiment: synthesize one netlist, route that exact netlist many times, record
the toolchain and configuration, and compare every required clock domain.

Why seeds matter
----------------

nextpnr uses the seed to influence randomized decisions in placement and
routing. Different seeds therefore explore different legal implementations of
the same synthesized design. A seed can improve one clock domain while making
another worse.

The seed does **not** repair an RTL timing problem, and seed numbers do not have
an inherent quality ordering. Seed 250 is not intrinsically better than seed 5.
A seed that passed an older netlist should be treated only as a historical
reference after any material change to RTL, generated LiteDRAM code, clocks,
memory geometry, framebuffer structure, constraints, synthesis settings, or
CAD tools.

For meaningful A/B experiments, use the **same seed set** for each configuration.
That makes a placer, router, or synthesis change easier to distinguish from
ordinary seed-to-seed variation.

What counts as a timing pass
----------------------------

A routed seed passes only when every required clock for that target meets its
constraint in the same route. The sweep scripts parse nextpnr timing results and
write a target-specific CSV result for each seed.

Current nominal timing requirements are:

.. list-table:: Required routed clocks
   :header-rows: 1
   :widths: 22 18 18 18 18 18

   * - Target
     - ``clk_sys``
     - LiteDRAM user
     - Video pixel
     - TMDS x5
     - LiteDRAM init
   * - ULX3S 85F
     - 50 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX3S 12F
     - 40 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX4M-LD 85F
     - Selected by workflow; 40 MHz default
     - 75.01 MHz
     - 50 MHz
     - 250 MHz
     - 25 MHz

A line such as ``1 warning, 0 errors`` is not enough to determine timing status.
Likewise, a route process can exit successfully while the timing result is
``FAIL`` because the sweep intentionally uses nextpnr's timing-allow-fail mode
to collect data from routes that miss timing.

Local sweep workflow
--------------------

The target dispatcher is ``scripts/sweep-ecp5.sh``. The target-specific scripts
provide convenient direct entry points:

.. code-block:: bash

   ./scripts/sweep-ecp5.sh --list-targets
   ./scripts/sweep-ulx3s-85f.sh 1-32
   ./scripts/sweep-ulx3s-12f.sh 1-32
   ./scripts/sweep-ulx4m-ld.sh 1-32

Local parallelism is controlled with ``SWEEP_JOBS``. For example:

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-ulx4m-ld.sh 1-32

Each local nextpnr process can consume hundreds of MiB of memory. Increasing
``SWEEP_JOBS`` can shorten wall-clock time, but only until CPU, RAM, storage, or
WSL/host scheduling becomes the bottleneck.

.. figure:: ../images/concurrent-nextpnr-ecp5.png
   :alt: Multiple concurrent nextpnr-ecp5 processes during a local sweep
   :width: 90%

   Multiple local nextpnr-ecp5 routes can run concurrently. Size
   ``SWEEP_JOBS`` for the machine rather than simply choosing the largest value.

The sweep flow normally synthesizes once and reuses that netlist for all seeds.
``SWEEP_SKIP_SYNTH=1`` is useful only when the existing netlist is known to
match the current target, source, clock, and feature settings. When in doubt,
regenerate the netlist.

GitHub Actions sweep
--------------------

The repository workflow is currently
``.github/workflows/ulx4m-ld-seed-sweep.yml``. Its displayed name is
``ECP5 seed sweep`` and its target selector supports ULX3S 85F, ULX3S 12F, and
ULX4M-LD 85F.

The workflow is manually started with ``workflow_dispatch``. It deliberately
separates synthesis from routing so every route job works from the same frozen
netlist.

Workflow concurrency is grouped by target and Git ref with
``cancel-in-progress: false``. A second run for the same target/ref is therefore
not used to cancel a sweep that is already collecting results.

Current workflow inputs
~~~~~~~~~~~~~~~~~~~~~~~

The defaults below describe the checked-in workflow at the time of this page.
The workflow file remains authoritative if a default changes later.

.. list-table:: GitHub sweep input guide
   :header-rows: 1
   :widths: 22 18 60

   * - Input
     - Current default
     - Purpose and selection guidance
   * - ``target``
     - ``ulx3s-85f``
     - Select ``ulx3s-85f``, ``ulx3s-12f``, or ``ulx4m-ld-85f``.
   * - ``seed_first`` / ``seed_last``
     - 1 / 260
     - Inclusive seed range. The current GitHub workflow validates the range as
       1 through 260. Start with a smaller controlled range for experiments.
   * - ``max_parallel``
     - 20
     - Maximum number of GitHub route jobs running concurrently. Choices are
       4, 8, 12, and 20.
   * - ``seeds_per_job``
     - 2
     - Seeds routed serially inside one route job. Choices are 1 through 5.
       Two limits the damage from a pathological long-running seed while still
       reducing runner setup overhead.
   * - ``retain_bitstreams``
     - false
     - Keep per-seed ``.bit`` files in artifacts. Leave disabled for broad
       exploratory sweeps unless the bitstreams are needed for hardware tests.
   * - ``ulx3s_85f_extended_modes``
     - 1
     - Enable the extended ULX3S 85F HDMI profile. Ignored by other targets.
   * - ``ulx3s_12f_memory_profile``
     - ``32m``
     - Select the 12F SDRAM map. Ignored by other targets.
   * - ``ulx4m_sys_clk_mhz``
     - 40
     - Hazard3 CPU/AHB system clock for ULX4M-LD. Choices are 25, 40, and
       50 MHz. The LiteDRAM user clock remains a separate 75 MHz domain.
   * - ``ulx4m_litedram_cpu``
     - ``serv``
     - Select the CPU embedded in the generated LiteDRAM initialization core:
       ``serv`` or ``vexrisc``. Ignored by other targets.
   * - ``placer``
     - ``heap``
     - Select nextpnr HeAP or simulated annealing (``sa``). HeAP is the normal
       baseline; SA can be substantially slower and is best used on a targeted
       seed subset.
   * - ``router``
     - ``router1``
     - Select ``router1`` or ``router2``. Compare routers with the same netlist
       and same seed set.
   * - ``heap_timingweight``
     - 10
     - HeAP timing weight. Available values are 10, 20, 30, and 40. Higher is
       not automatically better; test it as an A/B parameter.
   * - ``heap_critexp``
     - 2
     - HeAP criticality exponent. Available values are 2, 3, and 4.
   * - ``tmg_ripup``
     - false
     - Enable experimental timing-driven routing rip-up.
   * - ``router2_alt_weights``
     - false
     - Enable Router2 alternate weights. This is meaningful when Router2 is
       being evaluated.
   * - ``nextpnr_extra_args``
     - empty
     - Advanced escape hatch for additional whitespace-separated nextpnr
       arguments. Record experimental use carefully because it changes the
       routing experiment.
   * - ``synth_oss_cad_suite_version``
     - ``2026-07-20``
     - OSS CAD Suite snapshot used to synthesize the frozen netlist.
   * - ``route_oss_cad_suite_version``
     - ``2026-07-20``
     - OSS CAD Suite snapshot used by route jobs. It can intentionally differ
       from the synthesis snapshot for a controlled nextpnr version comparison.

``max_parallel`` and ``seeds_per_job`` solve different problems. For ``N`` seeds,
the workflow creates approximately ``ceil(N / seeds_per_job)`` route jobs. At
most ``max_parallel`` of those jobs run at once, while seeds within a job run
serially. For the common 1-260 range with two seeds per job, that is 130 route
jobs with at most 20 active concurrently.

Why two seeds per GitHub job
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A seed can occasionally take dramatically longer than its neighbors. Large
seed groups make such a straggler hold a runner and delay several seeds behind
it. Very small groups increase checkout, artifact, and runner startup overhead.
The default of two seeds per job is a practical compromise and keeps failures
localized.

The matrix uses ``fail-fast: false`` so one route group does not cancel all
other groups. This is important for characterization: a bad seed should not
hide useful results from unrelated seeds.

Workflow job architecture
-------------------------

The GitHub workflow has four logical jobs: ``prepare``, ``watch``, ``route``,
and ``summarize``.

.. list-table:: GitHub job-level timeouts
   :header-rows: 1
   :widths: 24 20 56

   * - Job
     - Timeout
     - Notes
   * - ``prepare``
     - 90 minutes
     - Synthesis, provenance capture, matrix generation, and frozen-input upload.
   * - ``watch``
     - 360 minutes
     - Live artifact collector; normally ends when the expected route groups are accounted for.
   * - ``route``
     - 350 minutes
     - Applies to a complete matrix group, including all serial seeds in that group.
   * - ``summarize``
     - 60 minutes
     - Final download, aggregation, completeness check, and artifact upload.

Because the route-job timeout covers the complete group, a large
``seeds_per_job`` value is risky when several seeds approach the per-seed
watchdog. This is another reason the default group size is small.

Prepare: synthesize once and freeze the experiment
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The ``prepare`` job:

* validates the target, seed range, and grouping inputs;
* restores or installs the selected synthesis OSS CAD Suite;
* initializes the Hazard3 submodule and the build-required nested submodules;
* synthesizes the selected target exactly once;
* records the sweep metadata and SHA256 of the synthesized netlist;
* records the Hazard3-Doom HEAD, Hazard3 gitlink/HEAD, and nested Hazard3
  ``libfpga`` and ``scripts`` gitlinks;
* records synthesis tool versions and every workflow parameter;
* builds the seed-group matrix; and
* uploads a frozen route-input archive for all route jobs.

This design prevents one route job from silently synthesizing a different
netlist from another route job. Every route runner extracts the same archive
and verifies the netlist SHA256 before invoking nextpnr.

The frozen input artifact and per-group route artifacts currently use one-day
retention because they primarily coordinate one workflow run. The complete
summarized sweep artifact is retained for 14 days and should be downloaded or
archived elsewhere when it becomes a long-term project checkpoint.

Route: independent runners, serial seeds within a group
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Each matrix route job runs on its own GitHub-hosted Ubuntu runner. Runners do
not share a filesystem. Each job therefore downloads the frozen input artifact,
verifies the netlist hash, restores the requested route OSS CAD Suite, and then
routes its assigned seeds one at a time with ``SWEEP_JOBS=1`` and
``SWEEP_SKIP_SYNTH=1``.

Per seed, the job records:

* console output;
* nextpnr/routing log files when present;
* result CSV;
* elapsed seconds;
* route exit status;
* the netlist SHA256 observed after routing; and
* optionally the generated bitstream.

The netlist hash is checked again after each seed. A route must never mutate the
frozen synthesized input.

Watch: live timing collector
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Because GitHub-hosted route jobs are isolated, the live monitor cannot inspect
the route runners directly. Instead, each completed seed group uploads a small
artifact. The dedicated ``watch`` job uses the GitHub token to observe newly
available group artifacts and prints their results while routing continues.

The watcher is invoked as:

.. code-block:: bash

   ./scripts/watch-ecp5-sweep-results.sh \
       "${SWEEP_TARGET}" \
       "${SWEEP_SEED_FIRST}" \
       "${SWEEP_SEED_LAST}" \
       "${SWEEP_SEEDS_PER_JOB}"

A typical live block looks like:

.. code-block:: text

   ------------------------------------------------------------
   LIVE TIMING RESULTS
   Timing-passing seeds: none
   Progress: 40/260 seeds | 20/130 groups | 20/130 jobs
   Status: PASS=0 FAIL=40 TIMEOUT=0 OTHER=0
   Route duration: avg=192s | fastest=118s (seed 6) | slowest=279s (seed 21)
   Best observed max MHz: sys=43.82 (seed 12) | litedram_user=71.70 (seed 10) | video=73.33 (seed 25)
                          tmds=370.23 (seed 4) | init=369.69 (seed 2)
   Timeout seeds: none
   Other/problem seeds: none
   ------------------------------------------------------------

Artifact groups can arrive out of numerical order because fast jobs finish
first. That is normal. Progress counts are therefore more useful than assuming
seed 1 will be reported before seed 100.

The ``Best observed max MHz`` fields are **per-clock maxima** and can come from
different seeds. They do not identify a combined timing pass. Always inspect the
``Timing-passing seeds`` list or the final per-seed summary when selecting a
candidate.

When a new timing pass appears, the watcher highlights it immediately rather
than waiting for the complete sweep. Route duration statistics also make it
easy to see whether one seed or one configuration is becoming pathologically
slow.

Summarize: authoritative final result
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

After route jobs finish, the ``summarize`` job downloads all seed-group
artifacts and the frozen reference inputs. ``scripts/summarize-ecp5-sweep.py``
produces the final Markdown and CSV summary, inventories the artifact, writes
SHA256 checksums, and checks that every requested seed has a result or an
explicit failure/timeout classification.

The complete final artifact includes enough provenance to answer questions such
as:

* Which exact netlist was routed?
* Which source and submodule revisions produced it?
* Which synthesis and route tool versions were used?
* Which nextpnr parameters were selected?
* Which seeds passed each individual clock?
* Which seeds passed all timing requirements?
* Which seeds timed out or failed at the tool level?
* How long did each route take?

Timeouts and long-running seeds
-------------------------------

The current workflow has two levels of route protection:

.. list-table:: Current route watchdogs
   :header-rows: 1
   :widths: 32 22 46

   * - Limit
     - Current value
     - Purpose
   * - Route timeout
     - 7200 seconds
     - Limits the nextpnr route inside the sweep implementation.
   * - Route kill-after
     - 30 seconds
     - Sends a hard kill if a timed-out route does not terminate promptly.
   * - Whole-seed timeout
     - 7600 seconds
     - Wraps the complete per-seed sweep invocation in the GitHub route job.
   * - Whole-seed kill-after
     - 30 seconds
     - Escalates termination for a stuck whole-seed invocation.
   * - GitHub route-job timeout
     - 350 minutes
     - Bounds the complete matrix job containing one or more serial seeds.

Whole-seed timeout exit statuses 124 and 137 are recorded as timeout conditions
and the job proceeds to the next seed. Other unexpected nonzero route statuses
remain actionable errors and can fail the route group.

This distinction is intentional: timing misses are experimental data, and
known-long seeds should not prevent later seeds from being tried. Tool crashes,
missing files, netlist mismatches, and other integration failures must remain
fatal or explicitly visible.

Parameter selection strategy
----------------------------

For a new netlist, start by establishing a baseline rather than immediately
launching the largest possible sweep. A useful progression is:

#. Route seeds 1-32 with the normal HeAP/Router1 settings.
#. Repeat the **same 1-32 seeds** for each controlled placer/router experiment.
#. Promote the best one or two configurations to a larger range such as 1-128.
#. Run the full 1-260 workflow only when a configuration is worth the compute
   cost or when a broad distribution is needed.

For HeAP experiments, compare the default timing weight/criticality pair first,
then test alternatives such as higher timing weights or criticality exponents
with the same seeds. Treat ``tmg_ripup`` and Router2 alternate weights as
explicit experiments, not automatic improvements.

Simulated annealing can be useful, but it can also be much slower than HeAP.
Use a small targeted seed set and retain the timeout protection when evaluating
SA.

If the route tool itself is under investigation, keep the frozen synthesized
netlist fixed and change only ``route_oss_cad_suite_version``. If synthesis is
under investigation, a new synthesis snapshot creates a new netlist; compare
its SHA256 and do not mix its seed rankings with the previous netlist.

Interpreting results
--------------------

A sweep result contains several different concepts that should not be confused:

``PASS``
   Every required clock for the target passed in that route.

``FAIL``
   Routing completed, but at least one required clock missed its target. This
   can still have route exit status 0 because timing failure is intentionally
   allowed for data collection.

``WHOLE_SEED_TIMEOUT`` or another timeout status
   The watchdog ended a route that exceeded its allowed run time. This is not a
   timing measurement and should not be ranked with completed routes.

``NO_RESULT``
   The route command returned but no valid per-seed result CSV was produced.
   Treat this as a diagnostic problem, not as a timing failure.

``ERROR`` / other problem
   A non-timeout tool or integration failure occurred. Inspect the console and
   nextpnr logs.

When comparing failing seeds, max-frequency numbers help identify which clock
is limiting the design. For ULX4M-LD, for example, a seed can pass the selected
Hazard3 ``clk_sys`` requirement while still missing the independent 75.01 MHz
LiteDRAM user clock. The best ``clk_sys`` seed is therefore not necessarily the
best overall candidate.

Reproducibility checklist
-------------------------

Before comparing two sweep runs, verify all of the following:

* same synthesized netlist SHA256, unless synthesis is the variable being tested;
* same target and target-specific feature profile;
* same clock requirements;
* same LiteDRAM CPU/generated core when using ULX4M-LD;
* same LPF/constraints;
* same route nextpnr version;
* same placer/router settings and extra arguments; and
* same seed subset for controlled A/B comparisons.

After a generated-core change such as a LiteDRAM memory-device/geometry update,
resynthesize and establish a new seed baseline. Old seed rankings are not
portable to the new netlist.

Developer tips and common traps
-------------------------------

* Do not interpret ``--timing-allow-fail`` as a timing waiver or a pass. It only
  lets the route finish so the sweep can collect the failing timing numbers.
* Do not select a seed from a per-clock maximum unless that same seed satisfies
  every required domain.
* Do not use ``SWEEP_SKIP_SYNTH=1`` after an RTL, generated-core, clock, or
  constraint change unless the matching netlist was deliberately regenerated
  first.
* Keep ``seeds_per_job`` small when seeds have shown long-tail route times. A
  large serial group can turn one pathological seed into a multi-hour straggler.
* ``max_parallel`` is a GitHub runner concurrency limit, not the number of
  nextpnr processes inside a route job. Each route job intentionally routes one
  seed at a time.
* High local ``SWEEP_JOBS`` values can exhaust memory before CPU utilization
  looks saturated.
* Retain bitstreams only when needed. Timing logs and CSVs are much smaller and
  are sufficient for most exploration.
* Hardware-test a selected production candidate. Static timing closure is
  necessary evidence, but board-level qualification still matters.
* Preserve final sweep artifacts when a result becomes a project checkpoint;
  they contain the hashes, configuration, tool versions, and per-seed evidence
  needed to reproduce or audit the result later.

Related files
-------------

The main sweep implementation is spread across these files:

.. code-block:: text

   .github/workflows/ulx4m-ld-seed-sweep.yml
   scripts/sweep-ecp5.sh
   scripts/sweep-ecp5-common.sh
   scripts/sweep-ulx3s-85f.sh
   scripts/sweep-ulx3s-12f.sh
   scripts/sweep-ulx4m-ld.sh
   scripts/watch-ecp5-sweep-results.sh
   scripts/summarize-ecp5-sweep.py

See :doc:`scripts` for the broader script catalog and
:doc:`board-profiles` for target clocks and current routed checkpoints.
