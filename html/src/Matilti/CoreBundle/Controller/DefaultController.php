<?php

namespace Matilti\CoreBundle\Controller;

use Symfony\Bundle\FrameworkBundle\Controller\Controller;

class DefaultController extends Controller
{
    public function indexAction()
    {
        return $this->render('MatiltiCoreBundle:Default:index.html.twig');
    }
    
    public function correoAction()
    {
        return $this->render('MatiltiCoreBundle:Default:correo.html.twig');
    }
}
