import type { Metadata } from 'next';
import '@fontsource/inter/400.css';
import '@fontsource/inter/500.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/700.css';
import './globals.css';
export const metadata: Metadata={title:'WorldVote — Progress deserves a voice.',description:'Follow the work. Share your perspective. Hold leadership accountable. A global community for meaningful civic participation.'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body>{children}</body></html>}
