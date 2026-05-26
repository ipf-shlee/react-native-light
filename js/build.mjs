import * as esbuild from 'esbuild';

const watch = process.argv.includes('--watch');

const config = {
  entryPoints: ['../ios/ReactNativeLightDemo/js/App.jsx'],
  bundle: true,
  outfile: '../ios/ReactNativeLightDemo/Resources/bundle.js',
  format: 'iife',
  target: ['es2017'],
  loader: { '.jsx': 'jsx' },
  jsxFactory: 'h',
  jsxFragment: 'Fragment',
  logLevel: 'info',
};

if (watch) {
  const ctx = await esbuild.context(config);
  await ctx.watch();
  console.log('[esbuild] watching …');
} else {
  await esbuild.build(config);
  console.log('[esbuild] built ../ios/ReactNativeLightDemo/Resources/bundle.js');
}
