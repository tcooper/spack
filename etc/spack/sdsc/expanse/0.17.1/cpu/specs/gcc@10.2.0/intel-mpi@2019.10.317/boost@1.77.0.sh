#!/usr/bin/env bash

#SBATCH --job-name=boost@1.77.0
#SBATCH --account=use300
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=32G
#SBATCH --time=00:30:00
#SBATCH --output=%x.o%j.%N

declare -xr LOCAL_TIME="$(date +'%Y%m%dT%H%M%S%z')"
declare -xir UNIX_TIME="$(date +'%s')"

declare -xr SYSTEM_NAME='expanse'

declare -xr SPACK_VERSION='0.17.1'
declare -xr SPACK_INSTANCE_NAME='cpu'
declare -xr SPACK_INSTANCE_DIR="${HOME}/cm/shared/apps/spack/${SPACK_VERSION}/${SPACK_INSTANCE_NAME}"

declare -xr SLURM_JOB_SCRIPT="$(scontrol show job ${SLURM_JOB_ID} | awk -F= '/Command=/{print $2}')"
declare -xr SLURM_JOB_MD5SUM="$(md5sum ${SLURM_JOB_SCRIPT})"

declare -xr SCHEDULER_MODULE='slurm'

echo "${UNIX_TIME} ${SLURM_JOB_ID} ${SLURM_JOB_MD5SUM} ${SLURM_JOB_DEPENDENCY}" 
echo ""

cat "${SLURM_JOB_SCRIPT}"

module purge
module load "${SCHEDULER_MODULE}"
module list
. "${SPACK_INSTANCE_DIR}/share/spack/setup-env.sh"

declare -xr SPACK_PACKAGE='boost@1.77.0'
declare -xr SPACK_COMPILER='gcc@10.2.0'
declare -xr SPACK_VARIANTS='+atomic +chrono ~clanglibcpp ~container ~context ~coroutine +date_time ~debug +exception ~fiber +filesystem +graph ~icu +iostreams +locale +log +math +mpi +multithreaded +numpy +pic +program_options +python +random +regex +serialization +shared +signals ~singlethreaded +system ~taggedlayout +test +thread +timer ~versionedlayout +wave'
declare -xr SPACK_DEPENDENCIES="^intel-mpi@2019.10.317/$(spack find --format '{hash:7}' intel-mpi@2019.10.317 % ${SPACK_COMPILER}) ^py-numpy@1.20.3/$(spack find --format '{hash:7}' py-numpy@1.20.3 % ${SPACK_COMPILER}) ^openblas@0.3.18/$(spack find --format '{hash:7}' openblas@0.3.18 % ${SPACK_COMPILER} +ilp64 threads=none)"
declare -xr SPACK_SPEC="${SPACK_PACKAGE} % ${SPACK_COMPILER} ${SPACK_VARIANTS} ${SPACK_DEPENDENCIES}"

printenv

spack config get compilers  
spack config get config  
spack config get mirrors
spack config get modules
spack config get packages
spack config get repos
spack config get upstreams

spack spec --long --namespaces --types "${SPACK_SPEC}"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack concretization failed.'
  exit 1
fi

time -p spack install --jobs "${SLURM_CPUS_PER_TASK}" --fail-fast --yes-to-all "${SPACK_SPEC}"
if [[ "${?}" -ne 0 ]]; then
  echo 'ERROR: spack install failed.'
  exit 1
fi

spack module lmod refresh --delete-tree -y

sbatch --dependency="afterok:${SLURM_JOB_ID}" 'superlu-dist@7.1.1.sh'

sleep 60
