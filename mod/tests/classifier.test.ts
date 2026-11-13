import { expect, test } from 'claude-code/testing'
import { irreversible, looksRisky, reasonFor } from '../hooks/irreversible.mjs'

type Ctx = { root?: string; tmpdir?: string }
type Row = [command: string, label: string | null, ctx?: Ctx]

const PUSH: Row[] = [
  ['git push', 'git push'],
  ['git push origin main', 'git push'],
  ['git push -u origin feature/login', 'git push'],
  ['git push 2>&1 | tail -5', 'git push'],
  ['git push origin main &', 'git push'],
  ['git push -f', 'git push --force'],
  ['git push --force origin main', 'git push --force'],
  ['git push --force-with-lease origin feat', 'git push --force'],
  ['git push --force-with-lease=feat:abc123 origin feat', 'git push --force'],
  ['git push origin +main', 'git push --force'],
  ['git push -uf origin main', 'git push --force'],
  ['git push origin --delete old-branch', 'git push --delete'],
  ['git push -d origin old-branch', 'git push --delete'],
  ['git push origin :old-branch', 'git push --delete'],
  ['git push --tags', 'git push (tags)'],
  ['git push --follow-tags', 'git push (tags)'],
  ['git push origin v0.34.0', 'git push (tags)'],
  ['git push origin tag v1.0.0', 'git push (tags)'],
  ['git push origin refs/tags/v1.0.0', 'git push (tags)'],
  ['git push --dry-run', null],
  ['git push -n origin main', null],
  ['git push --dry-run --force origin main', null],
]

const LOCAL_GIT: Row[] = [
  ['git reset --hard', 'git reset --hard'],
  ['git -C repo reset --hard HEAD~1', 'git reset --hard'],
  ['git reset --soft HEAD~1', null],
  ['git reset HEAD file.ts', null],
  ['git clean -f', 'git clean -f'],
  ['git clean -fdx', 'git clean -f'],
  ['git clean -n', null],
  ['git clean -fdn', null],
  ['git clean --dry-run -f', null],
  ['git branch -D old-work', 'git branch -D'],
  ['git branch --delete --force old-work', 'git branch -D'],
  ['git branch -d merged-work', null],
  ['git checkout -- .', 'git checkout (discard)'],
  ['git checkout .', 'git checkout (discard)'],
  ['git checkout HEAD -- src/a.ts', 'git checkout (discard)'],
  ['git checkout -f main', 'git checkout (discard)'],
  ['git checkout main', null],
  ['git checkout -b feature/x', null],
  ['git restore .', 'git restore'],
  ['git restore src/a.ts', 'git restore'],
  ['git restore --staged --worktree src/a.ts', 'git restore'],
  ['git restore --staged src/a.ts', null],
]

const RM: Row[] = [
  ['rm -rf src', 'rm -r'],
  ['rm -r docs/old', 'rm -r'],
  ['rm -R docs/old', 'rm -r'],
  ['rm --recursive --force packages/api', 'rm -r'],
  ['rm -f notes.md', 'rm -f'],
  ['rm notes.md', null],
  ['rm -rf node_modules', null],
  ['rm -rf dist build .next coverage .turbo', null],
  ['rm -rf ./dist/', null],
  ['rm -rf apps/web/.next', null],
  ['rm -rf node_modules/.cache', null],
  ['rm -rf node_modules src', 'rm -r'],
  ['rm -rf ../dist', 'rm -r'],
  ['rm -rf /', 'rm -r'],
  ['rm -rf ~', 'rm -r'],
  ['rm -rf ~/build', 'rm -r'],
  ['rm -rf /tmp', 'rm -r'],
  ['rm -rf /tmp/mm-scratch', null],
  ['rm -rf /private/tmp/claude-501/scratch', null],
  ['rm -rf "$TMPDIR/work"', null],
  ['rm -rf /var/folders/ab/cd/T/work', null, { tmpdir: '/var/folders/ab/cd/T/' }],
  ['rm -rf /var/folders/ab/cd/T/work', 'rm -r'],
  ['rm -rf /tmp/../etc', 'rm -r'],
  ['rm -rf /work/proj/node_modules', null, { root: '/work/proj' }],
  ['rm -rf /work/proj/node_modules', 'rm -r'],
  ['rm -rf /work/other/node_modules', 'rm -r', { root: '/work/proj' }],
  ['rm -rf -- -weird-name', 'rm -r'],
]

const PUBLISH: Row[] = [
  ['npm publish', 'npm publish'],
  ['pnpm publish --access public', 'pnpm publish'],
  ['pnpm -r publish', 'pnpm publish'],
  ['yarn publish', 'yarn publish'],
  ['yarn npm publish', 'yarn publish'],
  ['bun publish', 'bun publish'],
  ['npm publish --dry-run', null],
  ['npm run build', null],
  ['npm install', null],
  ['vercel --prod', 'vercel --prod'],
  ['vercel deploy --prod', 'vercel --prod'],
  ['npx vercel deploy --prod --yes', 'vercel --prod'],
  ['vercel', null],
  ['vercel deploy', null],
  ['gh release create v1.0.0 --notes "first"', 'gh release create'],
  ['gh pr merge 12 --squash', 'gh pr merge'],
  ['gh -R owner/repo pr merge 12', 'gh pr merge'],
  ['gh pr view 12', null],
  ['gh pr create --fill', null],
  ['gh release list', null],
  ['docker push ghcr.io/acme/api:1.2.0', 'docker push'],
  ['docker image push ghcr.io/acme/api:1.2.0', 'docker push'],
  ['docker build -t api .', null],
  ['terraform apply -auto-approve', 'terraform apply'],
  ['terraform -chdir=infra destroy', 'terraform destroy'],
  ['terraform plan', null],
  ['kubectl delete pod api-1', 'kubectl delete'],
  ['kubectl --context prod delete ns staging', 'kubectl delete'],
  ['kubectl apply -f deploy.yaml', 'kubectl apply'],
  ['kubectl apply -f deploy.yaml --dry-run=client', null],
  ['kubectl get pods', null],
  ['psql -c "DROP TABLE users"', 'psql DROP/TRUNCATE'],
  ['psql app -c "drop database app"', 'psql DROP/TRUNCATE'],
  ['mysql -e "TRUNCATE orders"', 'mysql DROP/TRUNCATE'],
  ['echo "DROP TABLE users;" | psql app', 'psql DROP/TRUNCATE'],
  ['psql -c "select count(*) from users"', null],
  ['mysql -e "show tables"', null],
]

const SHAPES: Row[] = [
  ['cd app && git push', 'git push'],
  ['npm test; git push origin main', 'git push'],
  ['git status | cat && git push origin main', 'git push'],
  ['npm test\ngit push', 'git push'],
  ['npm test || git reset --hard', 'git reset --hard'],
  ['(cd repo && git push)', 'git push'],
  ['if npm test; then git push; fi', 'git push'],
  ['echo $(git push)', 'git push'],
  ['FOO=1 npm publish --access public', 'npm publish'],
  ['GIT_SSH_COMMAND="ssh -i key" git push', 'git push'],
  ['env CI=1 git push', 'git push'],
  ['sudo rm -rf /var/lib/app', 'rm -r'],
  ['sudo -u deploy git push', 'git push'],
  ['/usr/bin/git push', 'git push'],
  ['echo "git push"', null],
  ["echo 'rm -rf /'", null],
  ['git commit -m "git push --force later"', null],
  ["grep -rn 'rm -rf' .", null],
  ['printf "%s\\n" "npm publish"', null],
  ['cat > notes.md <<EOF\ngit push origin main\nrm -rf src\nEOF', null],
  ['cat > notes.md <<EOF\nplan\nEOF\ngit push', 'git push'],
  ['ls # git push', null],
  ['git commit -m "$(cat <<\'EOF\'\nfix: read "npm test; git push origin main" as one chain (and more\nEOF\n)"', null],
  ['git commit -m "$(cat <<\'EOF\'\nfix: say "git push" first\nEOF\n)" && git push', 'git push'],
  ['git commit -m "release $(date +%F)" && git push --tags', 'git push (tags)'],
]

const REVIEWED: Row[] = [
  ['OUT="$(npm publish 2>&1)"; echo "$OUT"', 'npm publish'],
  ['echo "result: $(rm -rf src)"', 'rm -r'],
  ['out="`npm publish`"', 'npm publish'],
  ['npm run build >build.log 2>&1;npm publish', 'npm publish'],
  ['npm test >/dev/null&&npm publish', 'npm publish'],
  ['echo ok >/dev/null;rm -rf src', 'rm -r'],
  ['npm test > "test output.log"; rm -rf src', 'rm -r'],
  ['cat <<END-OF-MSG\nbody\nEND-OF-MSG\nnpm publish', 'npm publish'],
  ['pnpm --filter @acme/ui publish', 'pnpm publish'],
  ['npm -w pkg publish', 'npm publish'],
  ['npm --otp 123456 publish', 'npm publish'],
  ['yarn workspace @acme/ui npm publish', 'yarn publish'],
  ['npx vercel@latest --prod', 'vercel --prod'],
  ['vercel --target production', 'vercel --prod'],
  ['vercel --prod=true', 'vercel --prod'],
  ['psql -c "ALTER TABLE users DROP COLUMN email"', 'psql DROP/TRUNCATE'],
  ['psql -c "select 1" && echo "truncate done"', null],
  ['grep -c "drop table" x.sql && psql -c "select 1"', null],
  ['kubectl -v 6 delete pod x', 'kubectl delete'],
  ['kubectl --token abc delete pod x', 'kubectl delete'],
  ['time -p rm -rf src', 'rm -r'],
  ['kubectl delete --help', null],
  ['gh pr merge --help', null],
  ['rm -rf $PWD/dist', null],
  ['OUT="$(git push origin main 2>&1)"; echo "$OUT"', 'git push'],
  ['npm run build >build.log 2>&1&&git push --force', 'git push --force'],
  ['git branch -df feature', 'git branch -D'],
  ['git push -nf origin main', null],
  ['git push --help', null],
  ['git reset -q --hard', 'git reset --hard'],
]

const KNOWN_MISSES: Row[] = [
  ['$(echo git) push', null],
  ['gp origin main', null],
  ['make release', null],
  ['./scripts/release.sh', null],
  ['npm run deploy', null],
  ['eval "git push"', null],
  ['bash -c "git push"', null],
  ['find . -name "*.tmp" | xargs rm -rf', null],
  ["find . -name '*.log' -delete", null],
  ['timeout 30 git push', null],
  ['doas rm -rf /var/lib/app', null],
  ['env -i git push', null],
  ['psql -f drop-everything.sql', null],
]

function misread(rows: Row[]) {
  return rows
    .map(([command, label, ctx]) => ({ command, want: label, got: irreversible(command, ctx)?.label ?? null }))
    .filter((r) => r.got !== r.want)
}

test('classifier: git push in every form, and --dry-run left alone', async () => {
  expect(misread(PUSH)).toEqual([])
})

test('classifier: local git commands that discard work', async () => {
  expect(misread(LOCAL_GIT)).toEqual([])
})

test('classifier: rm on real paths is held, on regenerable and temp paths it is not', async () => {
  expect(misread(RM)).toEqual([])
})

test('classifier: publish, deploy, release, infrastructure and SQL', async () => {
  expect(misread(PUBLISH)).toEqual([])
})

test('classifier: chains, prefixes, sudo, and quoted text that only mentions a command', async () => {
  expect(misread(SHAPES)).toEqual([])
})

test('classifier: substitutions in quotes, tight redirects, workspace flags and other forms found in review', async () => {
  expect(misread(REVIEWED)).toEqual([])
})

test('classifier: the documented blind spots are misses, on purpose', async () => {
  expect(misread(KNOWN_MISSES)).toEqual([])
})

test('classifier: the table is at least 60 cases', async () => {
  expect(PUSH.length + LOCAL_GIT.length + RM.length + PUBLISH.length + SHAPES.length + KNOWN_MISSES.length >= 60).toBe(true)
})

test('classifier: plain push, publish and deploy are not destructive; the rest is', async () => {
  const destructive = (c: string) => irreversible(c)?.destructive
  for (const c of ['git push', 'git push --tags', 'npm publish', 'vercel --prod', 'gh pr merge 1', 'docker push a/b', 'terraform apply', 'kubectl apply -f a.yaml']) expect(destructive(c)).toBe(false)
  for (const c of ['git push -f', 'git push origin :x', 'git reset --hard', 'git clean -f', 'git branch -D x', 'git restore .', 'rm -rf src', 'terraform destroy', 'kubectl delete pod x', 'psql -c "drop table x"']) expect(destructive(c)).toBe(true)
})

test('classifier: the reason is one line in the kernel\'s words', async () => {
  const push = reasonFor(irreversible('git push')!)
  expect(push).toContain('ask before push, publish or deploy')
  expect(push).toContain('approval once is not approval again')
  expect(push.includes('\n')).toBe(false)
  expect(reasonFor(irreversible('rm -rf src')!)).toContain('ask before deleting or overwriting what you did not create')
})

test('classifier: the cheap check for the error path covers every held command', async () => {
  const held = [...PUSH, ...LOCAL_GIT, ...RM, ...PUBLISH, ...SHAPES].filter(([, label]) => label !== null).map(([c]) => c)
  expect(held.filter((c) => !looksRisky(c))).toEqual([])
  for (const c of ['ls -la', 'git status', 'npm test', 'cat README.md', 'git checkout main', 'terraform plan', 'rm -rf node_modules']) expect(looksRisky(c)).toBe(null)
})
