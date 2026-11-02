import {forwardRef,ButtonHTMLAttributes} from 'react';
import {cn} from '@/lib/utils';
export const Button=forwardRef<HTMLButtonElement,ButtonHTMLAttributes<HTMLButtonElement>&{variant?:'default'|'outline'|'ghost'}>(({className,variant='default',...props},ref)=><button ref={ref} className={cn('button',variant,className)} {...props}/>);Button.displayName='Button';
