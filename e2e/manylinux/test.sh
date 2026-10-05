#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Requires explicitly fetched images. This test never initiates a pull.
image_2_28=quay.io/pypa/manylinux_2_28_x86_64@sha256:39df0042d5cc900b085aa25a0659368b42a0006c54c474299b785b44c1b4ff82
image_2014=quay.io/pypa/manylinux2014_x86_64@sha256:f6077fab327d7823d7cee287b93ef63efe3af0e234add7503121247c1475ebec
docker image inspect "$image_2_28" "$image_2014" >/dev/null

scratch=$(mktemp -d)
bazel --output_base="$scratch/bazel" build --config=docker \
    //:dist_2_28 //:dist_2014 //:dist_alternate //:dist_copy //:host_action @quote_tools//:probe \
    --execution_log_json_file="$scratch/execution.json"
python3 check_execution.py "$scratch/execution.json"
bin=$(bazel --output_base="$scratch/bazel" info bazel-bin)
for policy in 2_28 2014 alternate; do
    image=$image_2_28
    if [[ $policy == 2014 ]]; then image=$image_2014; fi
    for abi in cp311-cp311 cp312-cp312 cp313-cp313; do
        docker run --rm --pull=never --network=none \
            -v "$bin/dist_$policy:/wheels:ro" -v "$PWD/check_wheel.py:/check.py:ro" \
            "$image" bash -c "/opt/python/$abi/bin/python /check.py /wheels/*.whl"
    done
done
if bazel --output_base="$scratch/bazel" build --config=docker //:rejected_2014 >"$scratch/rejection.log" 2>&1; then
    echo 'A wheel requiring glibc 2.25 incorrectly passed manylinux2014' >&2
    exit 1
fi
rg -F 'too-recent versioned symbols' "$scratch/rejection.log"
probe=$(bazel --output_base="$scratch/bazel" cquery @quote_tools//:probe --output=starlark --starlark:expr='target.files.to_list()[0].path')
docker run --rm --pull=never --network=none \
    -v "$(readlink -f "$scratch/bazel/$probe"):/probe:ro" "$image_2_28" /probe 'trailing argument'
python3 -m unittest discover -s ../../py/private/container -p 'test_*.py'
bazel --output_base="$scratch/bazel" shutdown
echo "Execution and rejection logs: $scratch"
